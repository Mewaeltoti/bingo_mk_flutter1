const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

exports.buyCard = onCall({ cors: true }, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in.');

    const userId = request.auth.uid;
    const db = admin.firestore();
    const gameRef = db.collection('games').doc('live');

    try {
        const gameSnap = await gameRef.get();
        if (!gameSnap.exists || gameSnap.data().status !== 'buying') {
            throw new Error("Game is not in buying phase.");
        }

        const randomId = Math.floor(Math.random() * 26000) + 1;
        const poolDoc = await db.collection('cartelas_pool').doc(randomId.toString()).get();
        if (!poolDoc.exists) throw new Error("Pool card not found.");

        const cardRef = db.collection('users').doc(userId).collection('cards').doc(randomId.toString());
        
        const gameData = gameSnap.data();

        await cardRef.set({
            gameId: 'live',
            sessionId: (gameData.sessionId || '').toString(),
            cardNo: randomId,
            numbers: poolDoc.data().numbers,
            status: 'pending', // NOT REGISTERED YET
            purchasedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        return { success: true, cardId: randomId.toString() };
    } catch (error) {
        throw new HttpsError('aborted', error.message);
    }
});

exports.registerCard = onCall({ cors: true }, async (request) => {
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

            if (!userDoc.exists || !gameDoc.exists || !cardDoc.exists) {
                throw new Error("Missing data for registration (User, Game, or Card).");
            }

            const card = cardDoc.data();
            if (card.status === 'registered') throw new Error("Card is already registered.");

            const price = gameDoc.data().cardPrice || 10;
            const balance = userDoc.data().balance || 0;

            if (balance < price) throw new Error("Insufficient balance.");

            transaction.update(userRef, { balance: balance - price });
            transaction.update(cardRef, { status: 'registered' });
            transaction.update(gameRef, { cardsSold: admin.firestore.FieldValue.increment(1) });

            return { success: true };
        });
        return result;
    } catch (error) {
        console.error("RegisterCard Error:", error);
        throw new HttpsError('internal', error.message);
    }
});

exports.startNewGame = onCall({ cors: true }, async (request) => {
    const db = admin.firestore();
    const gameRef = db.collection('games').doc('live');
    const counterRef = db.collection('metadata').doc('counters');

    try {
        const result = await db.runTransaction(async (transaction) => {
            let sessionNum = 1000;
            const counterDoc = await transaction.get(counterRef);
            
            if (counterDoc.exists) {
                sessionNum = (counterDoc.data().currentSessionId || 1000) + 1;
            }
            
            transaction.set(counterRef, { currentSessionId: sessionNum }, { merge: true });
            
            transaction.update(gameRef, {
                status: 'buying',
                sessionId: sessionNum,
                drawnNumbers: [],
                winners: [],
                winnerId: null,
                cardsSold: 0,
                playersCount: 0,
                isPaused: false,
                startTime: admin.firestore.FieldValue.serverTimestamp()
            });

            return { success: true, sessionId: sessionNum };
        });
        return result;
    } catch (error) {
        console.error("StartNewGame Error:", error);
        throw new HttpsError('internal', error.message);
    }
});


exports.seedPool = onCall({ cors: true, timeoutSeconds: 540, memory: '1GiB' }, async (request) => {
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
});
exports.cancelGame = onCall({ cors: true }, async (request) => {
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
                isPaused: false
            });

            return { success: true, oldSession: game.sessionId, newSession: nextSession };
        });
        return result;
    } catch (error) {
        console.error("CancelGame Error:", error);
        throw new HttpsError('internal', error.message);
    }
});

exports.removeCard = onCall({ cors: true }, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in.');

    const { cardId } = request.data;
    if (!cardId) throw new HttpsError('invalid-argument', 'cardId is required.');

    const userId = request.auth.uid;
    const db = admin.firestore();
    const cardRef = db.collection('users').doc(userId).collection('cards').doc(cardId.toString());

    try {
        const cardDoc = await cardRef.get();
        if (!cardDoc.exists) {
            throw new Error("Card not found.");
        }

        if (cardDoc.data().status !== 'pending') {
            throw new Error("Only pending cards can be removed.");
        }

        await cardRef.delete();
        return { success: true };
    } catch (error) {
        throw new HttpsError('internal', error.message);
    }
});
