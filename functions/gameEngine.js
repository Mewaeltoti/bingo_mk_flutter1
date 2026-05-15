const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

// Triggered when a new user is created in Firebase Auth
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
    const db = admin.firestore();
    const userRef = db.collection('users').doc(user.uid);

    try {
        await userRef.set({
            phone: user.phoneNumber || '',
            email: user.email || '',
            role: 'player',
            balance: 0,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        console.log(`User document created for ${user.uid}`);
    } catch (error) {
        console.error(`Error creating user document for ${user.uid}:`, error);
    }
});

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

                    // Unregister all cards that are not pending (set back to pending)
                    const activeCards = await db.collectionGroup('cards').where('status', '!=', 'pending').get();
                    if (!activeCards.empty) {
                        let batch = db.batch();
                        let count = 0;
                        for (const doc of activeCards.docs) {
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
                        isPaused: false,
                        claimDeadline: null,
                        pendingClaims: [],
                        confirmedWinners: []
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
