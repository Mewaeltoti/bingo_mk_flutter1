const { HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

exports.buyCard = async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in.');

    const userId = request.auth.uid;
    const db = admin.firestore();
    const gameRef = db.collection('games').doc('live');

    try {
        const gameSnap = await gameRef.get();
        if (!gameSnap.exists || gameSnap.data().status !== 'buying') {
            throw new Error("Game is not in buying phase.");
        }

        const { count = 1 } = request.data || {};
        const requestedCount = Math.min(Math.max(1, count), 25);
        const sessionId = (gameSnap.data().sessionId || '').toString();

        // Enforce the 25-card hard limit per user per session
        const existingCardsSnap = await db.collection('users').doc(userId).collection('cards')
            .where('sessionId', '==', sessionId)
            .get();

        const existingCount = existingCardsSnap.size;
        if (existingCount + requestedCount > 25) {
            throw new Error(`You can only own a maximum of 25 cards per session. You already have ${existingCount} cards.`);
        }
        const buyCount = requestedCount;

        // SECURITY FIX: Use a transactional queue to prevent duplicate card assignment.
        // cartela_queue/{sessionId} holds an array of available card IDs for this session.
        // We atomically splice 'buyCount' IDs off the front, guaranteeing no two users
        // can ever receive the same card in the same session.
        const queueRef = db.collection('cartela_queue').doc(sessionId);

        const assignedIds = await db.runTransaction(async (transaction) => {
            const queueDoc = await transaction.get(queueRef);

            let available = [];
            if (queueDoc.exists) {
                available = queueDoc.data().available || [];
            } else {
                // First buyer this session: build the shuffled queue from the pool index.
                // We store card IDs 1–26000 in a Fisher-Yates shuffled order so picks are O(1).
                available = Array.from({ length: 26000 }, (_, i) => i + 1);
                for (let i = available.length - 1; i > 0; i--) {
                    const j = Math.floor(Math.random() * (i + 1));
                    [available[i], available[j]] = [available[j], available[i]];
                }
            }

            if (available.length < buyCount) {
                throw new Error("Not enough cards available in this session.");
            }

            // Atomically claim the next 'buyCount' IDs from the front of the queue
            const taken = available.splice(0, buyCount);
            transaction.set(queueRef, { available, sessionId, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
            return taken;
        });

        // Now fetch the pool docs and write the user cards
        const poolPromises = assignedIds.map(id =>
            db.collection('cartelas_pool').doc(id.toString()).get()
        );
        const poolSnaps = await Promise.all(poolPromises);
        const batch = db.batch();
        const results = [];

        for (let i = 0; i < poolSnaps.length; i++) {
            const poolDoc = poolSnaps[i];
            const cardId = assignedIds[i];
            if (!poolDoc.exists) continue;

            const cardRef = db.collection('users').doc(userId).collection('cards').doc(cardId.toString());
            batch.set(cardRef, {
                gameId: 'live',
                game_id: 'live',
                sessionId: sessionId,
                cardNo: cardId,
                numbers: poolDoc.data().numbers,
                status: 'pending',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 60 * 1000))
            });
            results.push(cardId.toString());
        }

        await batch.commit();
        return { success: true, cardIds: results };
    } catch (error) {
        throw new HttpsError('aborted', error.message);
    }
};

exports.registerCard = async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in.');

    const { cardId } = request.data || {};
    if (!cardId) throw new HttpsError('invalid-argument', 'cardId is required.');
    

    const userId = request.auth.uid;
    const db = admin.firestore();

    const userRef = db.collection('users').doc(userId);
    const gameRef = db.collection('games').doc('live');
    const cardRef = userRef.collection('cards').doc(cardId.toString());

    try {
        const result = await db.runTransaction(async (transaction) => {
            const cardDoc = await transaction.get(cardRef);
            
            // Idempotency: If this card is already registered by this user, return success immediately!
            if (cardDoc.exists && cardDoc.data().status === 'registered') {
                return { success: true };
            }

            const userDoc = await transaction.get(userRef);
            const gameDoc = await transaction.get(gameRef);

            const poolDoc = await transaction.get(db.collection('cartelas_pool').doc(cardId.toString()));
            if (!poolDoc.exists) throw new Error("Invalid card number. Not found in pool.");
            const numbers = poolDoc.data().numbers;

            if (!gameDoc.exists) throw new Error("Live game document (games/live) does not exist.");
            const gameData = gameDoc.data();
            if (gameData.status !== 'buying') throw new Error("Game is not in buying phase.");

            const sessionId = (gameData.sessionId || '').toString();

            // Enforce 25-card max per user per session — server-side guard
            // (client UI also blocks this, but clients can be bypassed).
            const existingCardsSnap = await transaction.get(
                userRef.collection('cards').where('sessionId', '==', sessionId)
            );
            const existingCardCount = existingCardsSnap.size;
            if (existingCardCount >= 25) {
                throw new Error(
                    `You already have ${existingCardCount} cards this session. ` +
                    `Maximum allowed is 25.`
                );
            }

            // Atomic transaction check using cardAssignments/{sessionId_cardNo}
            const assignmentRef = db.collection('cardAssignments').doc(`${sessionId}_${cardId}`);
            const assignmentDoc = await transaction.get(assignmentRef);

            if (assignmentDoc.exists) {
                const assignedUserId = assignmentDoc.data().userId;
                if (assignedUserId !== userId) {
                    throw new Error("This card number has already been purchased by another player!");
                }
            }

            let balance = 0;
            if (!userDoc.exists) {
                transaction.set(userRef, {
                    balance: 0,
                    role: 'player',
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });
                balance = 0;
            } else {
                balance = userDoc.data().balance || 0;
            }

            const price = gameData.cardPrice || 10;
            if (balance < price) throw new Error("Insufficient balance.");

            // Standardize 24-number format to 25-number format by putting the free space (0) at index 12
            const numbers25 = [...numbers];
            if (numbers25.length === 24) {
                numbers25.splice(12, 0, 0);
            }

            transaction.update(userRef, { balance: admin.firestore.FieldValue.increment(-price) });
            transaction.set(cardRef, {
                gameId: 'live',
                game_id: 'live',
                sessionId: sessionId,
                cardNo: Number(cardId),
                numbers: numbers25,
                status: 'registered',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 60 * 1000))
            });
            transaction.update(gameRef, { cardsSold: admin.firestore.FieldValue.increment(1) });

            // Record assignment atomically
            transaction.set(assignmentRef, {
                userId: userId,
                cardNo: Number(cardId),
                sessionId: sessionId,
                registeredAt: admin.firestore.FieldValue.serverTimestamp()
            });

            return { success: true };
        });
        return result;
    } catch (error) {
        console.error("RegisterCard Error:", error);
        throw new HttpsError('internal', error.message);
    }
};

exports.startNewGame = async (request) => {
    const { prizePool, cardPrice, gamePattern } = request.data || {};
    const db = admin.firestore();
    const gameRef = db.collection('games').doc('live');
    const counterRef = db.collection('metadata').doc('counters');

    try {
        const result = await db.runTransaction(async (transaction) => {
            const counterDoc = await transaction.get(counterRef);
            const gameDoc = await transaction.get(gameRef);

            let sessionNum = 1000;
            if (counterDoc.exists) {
                sessionNum = (counterDoc.data().currentSessionId || 1000) + 1;
            }

            transaction.set(counterRef, { currentSessionId: sessionNum }, { merge: true });

            // SECURITY: Generate draw sequence and store in server-only collection.
            // Never written to games/live where clients have read access.
            const drawSequence = Array.from({ length: 75 }, (_, i) => i + 1);
            for (let i = drawSequence.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [drawSequence[i], drawSequence[j]] = [drawSequence[j], drawSequence[i]];
            }
            const seqRef = db.collection('game_sequences').doc(sessionNum.toString());
            transaction.set(seqRef, {
                sessionId: sessionNum,
                drawSequence: drawSequence,
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });

            const gameUpdate = {
                status: 'buying',
                sessionId: sessionNum,
                drawnNumbers: [],
                // drawSequence intentionally omitted — kept in game_sequences only
                winners: [],
                winnerId: null,
                cardsSold: 0,
                playersCount: 0,
                isPaused: false,
                prizePool: prizePool || 250,
                cardPrice: cardPrice || 10,
                gamePattern: gamePattern || 'full_house',
                currentNumber: null,
                lastDrawTime: null,
                winningCardNo: null,
                winningCardNumbers: null,
                startTime: admin.firestore.FieldValue.serverTimestamp(),
                endTime: null,
                claimDeadline: null,
                pendingClaims: [],
                confirmedWinners: [],
                statusMessage: "Waiting for players..."
            };

            if (!gameDoc.exists) {
                transaction.set(gameRef, gameUpdate);
            } else {
                transaction.update(gameRef, gameUpdate);
            }

            return { success: true, sessionId: sessionNum };
        });



        // TTL handles card deletion; no manual batch deletion needed.

        return result;
    } catch (error) {
        console.error("StartNewGame Error:", error);
        throw new HttpsError('internal', error.message);
    }
};


exports.seedPool = async (request) => {
    const db = admin.firestore();
    const { startIndex = 0, count = 5000 } = request.data || {};

    try {
        const dataPath = path.join(__dirname, "data.json");
        if (!fs.existsSync(dataPath)) throw new Error("data.json not found in functions folder.");

        const rawData = fs.readFileSync(dataPath, "utf8");
        const allCards = JSON.parse(rawData);

        // Slice the cards array based on requested chunk
        const cardsChunk = allCards.slice(startIndex, startIndex + count);

        const poolRef = db.collection("cartelas_pool");
        let batch = db.batch();
        let processed = 0;

        for (const card of cardsChunk) {
            const originalNumbers = card.bingo_numbers;
            const numbers25 = [...originalNumbers];

            if (numbers25.length === 24) {
                numbers25.splice(12, 0, 0);
            }

            const cardDoc = poolRef.doc(card.cartela_no.toString());
            batch.set(cardDoc, {
                cardNo: card.cartela_no,
                numbers: numbers25,
            });

            processed++;
            if (processed % 500 === 0) {
                await batch.commit();
                batch = db.batch();
            }
        }

        if (processed % 500 !== 0) {
            await batch.commit();
        }

        return {
            success: true,
            seeded: processed,
            nextIndex: startIndex + processed,
            totalAvailable: allCards.length
        };
    } catch (error) {
        throw new HttpsError('internal', error.message);
    }
};
exports.cancelGame = async (request) => {
    const db = admin.firestore();
    const gameRef = db.collection('games').doc('live');
    const historyRef = db.collection('game_history').doc();
    const counterRef = db.collection('metadata').doc('counters');

    try {
        const result = await db.runTransaction(async (transaction) => {
            // ALL READS FIRST
            const gameDoc = await transaction.get(gameRef);
            const counterDoc = await transaction.get(counterRef);

            if (!gameDoc.exists) throw new Error("No live game found.");
            const game = gameDoc.data();

            // LOGIC
            let nextSession = (game.sessionId || 1000) + 1;
            if (counterDoc.exists) {
                nextSession = (counterDoc.data().currentSessionId || 1000) + 1;
            }

            // ALL WRITES AFTER
            transaction.set(historyRef, {
                sessionId: game.sessionId || 'N/A',
                status: 'cancelled',
                prize: game.prizePool || 0,
                drawnNumbers: game.drawnNumbers || [],
                cardsSold: game.cardsSold || 0,
                cancelledAt: admin.firestore.FieldValue.serverTimestamp()
            });

            transaction.set(counterRef, { currentSessionId: nextSession }, { merge: true });

            transaction.update(gameRef, {
                status: 'waiting',
                sessionId: nextSession,
                drawnNumbers: [],
                winners: [],
                winnerId: null,
                cardsSold: 0,
                isPaused: false,
                currentNumber: null,
                lastDrawTime: null,
                winningCardNo: null,
                winningCardNumbers: null,
                startTime: null,
                endTime: null,
                claimDeadline: null,
                pendingClaims: [],
                confirmedWinners: [],
                statusMessage: "Game cancelled."
            });

            return { success: true, oldSession: game.sessionId, newSession: nextSession };
        });



        // TTL handles card deletion; no manual batch deletion needed.

        return result;
    } catch (error) {
        console.error("CancelGame Error:", error);
        throw new HttpsError('internal', error.message);
    }
};

exports.removeCard = async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in.');

    const { cardId } = request.data;
    if (!cardId) throw new HttpsError('invalid-argument', 'cardId is required.');

    const userId = request.auth.uid;
    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);
    const gameRef = db.collection('games').doc('live');
    const cardRef = userRef.collection('cards').doc(cardId.toString());

    try {
        await db.runTransaction(async (transaction) => {
            const cardDoc = await transaction.get(cardRef);
            if (!cardDoc.exists) throw new Error("Card not found.");
            const cardData = cardDoc.data();

            const gameDoc = await transaction.get(gameRef);
            if (!gameDoc.exists) throw new Error("Live game not found.");
            const gameData = gameDoc.data();

            // Fetch userDoc upfront to satisfy the read-before-write constraint!
            const userDoc = await transaction.get(userRef);

            if (cardData.status === 'registered') {
                // Decrement cards sold
                transaction.update(gameRef, {
                    cardsSold: admin.firestore.FieldValue.increment(-1)
                });

                // Refund user if in buying phase
                if (gameData.status === 'buying') {
                    if (userDoc.exists) {
                        const currentBalance = userDoc.data().balance || 0;
                        const price = gameData.cardPrice || 10;
                        transaction.update(userRef, { balance: currentBalance + price });
                    }
                }

                // Clean up card assignment atomically!
                const assignmentRef = db.collection('cardAssignments').doc(`${cardData.sessionId}_${cardId}`);
                transaction.delete(assignmentRef);
            }

            transaction.delete(cardRef);
        });

        return { success: true };
    } catch (error) {
        console.error("RemoveCard Error:", error);
        throw new HttpsError('internal', error.message);
    }
};

exports.resetAllRegisteredCards = async (db) => {
    // game_winners collection removed — game_history is the source of truth.
    // TTL handles user card cleanup automatically.
};
