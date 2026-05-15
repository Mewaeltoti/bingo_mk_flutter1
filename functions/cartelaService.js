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
        const buyCount = Math.min(Math.max(1, count), 50);
        const sessionId = (gameSnap.data().sessionId || '').toString();
        const batch = db.batch();
        const poolPromises = [];
        const cardIds = [];

        for (let i = 0; i < buyCount; i++) {
            const randomId = Math.floor(Math.random() * 26000) + 1;
            poolPromises.push(db.collection('cartelas_pool').doc(randomId.toString()).get());
            cardIds.push(randomId);
        }

        const poolSnaps = await Promise.all(poolPromises);
        const results = [];

        for (let i = 0; i < poolSnaps.length; i++) {
            const poolDoc = poolSnaps[i];
            if (!poolDoc.exists) continue;

            const randomId = cardIds[i];
            const cardRef = db.collection('users').doc(userId).collection('cards').doc(randomId.toString());

            batch.set(cardRef, {
                gameId: 'live',
                sessionId: sessionId,
                cardNo: randomId,
                numbers: poolDoc.data().numbers,
                status: 'pending',
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
            results.push(randomId.toString());
        }

        await batch.commit();
        return { success: true, cardIds: results };
    } catch (error) {
        throw new HttpsError('aborted', error.message);
    }
};

exports.registerCard = async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in.');

    const { cardId } = request.data;
    if (!cardId) throw new HttpsError('invalid-argument', 'cardId is required.');

    const userId = request.auth.uid;
    const db = admin.firestore();

    const userRef = db.collection('users').doc(userId);
    const gameRef = db.collection('games').doc('live');
    const cardRef = userRef.collection('cards').doc(cardId.toString());

    try {
        const result = await db.runTransaction(async (transaction) => {
            const userDoc = await transaction.get(userRef);
            const gameDoc = await transaction.get(gameRef);
            const cardDoc = await transaction.get(cardRef);

            let balance = 0;
            if (!userDoc.exists) {
                // Initialize user document if it doesn't exist
                transaction.set(userRef, {
                    balance: 0,
                    role: 'player',
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });
                balance = 0;
            } else {
                balance = userDoc.data().balance || 0;
            }

            if (!gameDoc.exists) throw new Error("Live game document (games/live) does not exist.");
            if (!cardDoc.exists) throw new Error("Card document does not exist for cardId: " + cardId);

            const card = cardDoc.data();
            if (card.status === 'registered') throw new Error("Card is already registered.");

            const price = gameDoc.data().cardPrice || 10;

            if (balance < price) throw new Error("Insufficient balance.");

            transaction.update(userRef, { balance: balance - price });
            transaction.update(cardRef, {
                status: 'registered',
                sessionId: (gameDoc.data().sessionId || '').toString()
            });
            transaction.update(gameRef, { cardsSold: admin.firestore.FieldValue.increment(1) });

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

            const gameUpdate = {
                status: 'buying',
                sessionId: sessionNum,
                drawnNumbers: [],
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

        // Unregister all 'registered' cards for the new session
        const registeredCardsSnapshot = await db.collectionGroup('cards')
            .where('status', '==', 'registered')
            .get();

        if (!registeredCardsSnapshot.empty) {
            let cardBatch = db.batch();
            let count = 0;
            for (const doc of registeredCardsSnapshot.docs) {
                cardBatch.update(doc.ref, { status: 'pending', sessionId: '' });
                count++;
                if (count === 400) {
                    await cardBatch.commit();
                    cardBatch = db.batch();
                    count = 0;
                }
            }
            if (count > 0) {
                await cardBatch.commit();
            }
        }

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

        // Unregister all 'registered' cards for the new session
        const registeredCardsSnapshot = await db.collectionGroup('cards')
            .where('status', '==', 'registered')
            .get();

        if (!registeredCardsSnapshot.empty) {
            let cardBatch = db.batch();
            let count = 0;
            for (const doc of registeredCardsSnapshot.docs) {
                cardBatch.update(doc.ref, { status: 'pending', sessionId: '' });
                count++;
                if (count === 400) {
                    await cardBatch.commit();
                    cardBatch = db.batch();
                    count = 0;
                }
            }
            if (count > 0) {
                await cardBatch.commit();
            }
        }

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

            if (cardData.status === 'registered') {
                // Decrement cards sold
                transaction.update(gameRef, {
                    cardsSold: admin.firestore.FieldValue.increment(-1)
                });

                // Refund user if in buying phase
                if (gameData.status === 'buying') {
                    const userDoc = await transaction.get(userRef);
                    if (userDoc.exists) {
                        const currentBalance = userDoc.data().balance || 0;
                        const price = gameData.cardPrice || 10;
                        transaction.update(userRef, { balance: currentBalance + price });
                    }
                }
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
    // Reset ALL cards that are not already pending (includes 'registered' and 'claiming' cards)
    const cardsToReset = await db.collectionGroup('cards')
        .where('status', '!=', 'pending')
        .get();

    if (!cardsToReset.empty) {
        let cardBatch = db.batch();
        let count = 0;
        for (const doc of cardsToReset.docs) {
            cardBatch.update(doc.ref, { status: 'pending', sessionId: '' });
            count++;
            if (count === 400) {
                await cardBatch.commit();
                cardBatch = db.batch();
                count = 0;
            }
        }
        if (count > 0) {
            await cardBatch.commit();
        }
    }
};
