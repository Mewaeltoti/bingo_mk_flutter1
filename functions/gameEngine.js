const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

// Runs every 1 minute, loops internally for 60 seconds (5 sec intervals)
exports.drawNumberLoop = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
    const db = admin.firestore();

    const endTime = Date.now() + 55000;
    
    while (Date.now() < endTime) {
        // ALWAYS fetch from games/live
        const gameDoc = await db.collection('games').doc('live').get();
        if (!gameDoc.exists) break;

        const game = gameDoc.data();

        // Check if game has ended and needs a reset
        if (game.status === 'won' || game.status === 'finished') {
            if (game.endTime) {
                const end = game.endTime.toDate().getTime();
                // Reset after 60 seconds
                if (Date.now() - end >= 60 * 1000) {
                    const counterRef = db.collection('metadata').doc('counters');
                    const counterDoc = await counterRef.get();
                    let sessionNum = 1000;
                    if (counterDoc.exists) {
                        sessionNum = (counterDoc.data().currentSessionId || 1000) + 1;
                    }
                    await counterRef.set({ currentSessionId: sessionNum }, { merge: true });

                    // Unregister all registered cards (set back to pending)
                    const registeredCards = await db.collectionGroup('cards').where('status', '==', 'registered').get();
                    if (!registeredCards.empty) {
                        let batch = db.batch();
                        let count = 0;
                        for (const doc of registeredCards.docs) {
                            batch.update(doc.ref, { status: 'pending', sessionId: '' });
                            count++;
                            if (count % 400 === 0) {
                                await batch.commit();
                                batch = db.batch();
                            }
                        }
                        if (count % 400 !== 0) {
                            await batch.commit();
                        }
                    }

                    await gameDoc.ref.update({
                        status: 'waiting',
                        sessionId: sessionNum,
                        drawnNumbers: [],
                        cardsSold: 0,
                        playersCount: 0,
                        isPaused: false
                        // Note: winners, winnerId, winningCardNo, and winningCardNumbers are preserved 
                        // so they can be viewed during the waiting phase. They are cleared in startNewGame.
                    });
                }
            }
            
            await new Promise(resolve => setTimeout(resolve, 5000));
            continue;
        }

        if (game.status !== 'active') {
            await new Promise(resolve => setTimeout(resolve, 5000));
            continue; // Wait if not active
        }

        const drawnNumbers = game.drawnNumbers || [];
        
        // Generate available numbers (1-75)
        const availableNumbers = Array.from({length: 75}, (_, i) => i + 1)
            .filter(n => !drawnNumbers.includes(n));

        if (availableNumbers.length === 0) {
            await gameDoc.ref.update({ 
                status: 'finished',
                endTime: admin.firestore.FieldValue.serverTimestamp()
            });
        } else {
            // Draw random number safely without duplicates
            const randomIndex = Math.floor(Math.random() * availableNumbers.length);
            const newNumber = availableNumbers[randomIndex];
            drawnNumbers.push(newNumber);

            await gameDoc.ref.update({
                currentNumber: newNumber,
                drawnNumbers: drawnNumbers,
                lastDrawTime: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        // Wait for 5 seconds
        await new Promise(resolve => setTimeout(resolve, 5000));
    }

    return null;
});
