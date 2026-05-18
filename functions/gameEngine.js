const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

// Triggered when a new user is created in Firebase Auth
// Logic for user creation trigger
exports.onUserCreatedHandler = async (user) => {
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
};

// Runs every 1 minute, loops internally for 60 seconds (5 sec intervals)
// Logic for drawing numbers loop
exports.drawNumberLoopHandler = async (context) => {
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
                        status: 'buying',
                        sessionId: sessionNum,
                        startTime: admin.firestore.FieldValue.serverTimestamp(),
                        drawnNumbers: [],
                        cardsSold: 0,
                        playersCount: 0,
                        isPaused: false,
                        claimDeadline: null,
                        pendingClaims: [],
                        confirmedWinners: [],
                        statusMessage: "Waiting for players..."
                    });
                }
            }
            
            await new Promise(resolve => setTimeout(resolve, 5000));
            continue;
        }

        // AUTO-START GAME AFTER 2 MINUTES OF BUYING
        if (game.status === 'buying') {
            const startTime = game.startTime ? game.startTime.toDate().getTime() : Date.now();
            if (Date.now() - startTime >= 120 * 1000) {
                // Time to start the game
                await gameDoc.ref.update({
                    status: 'active',
                    statusMessage: "Game started! Drawing numbers..."
                });
                console.log(`Game started automatically for session ${game.sessionId}`);
            } else {
                console.log(`Game is in buying phase. Waiting for players...`);
            }
            await new Promise(resolve => setTimeout(resolve, 5000));
            continue;
        }

        // AUTO-FINALIZE CLAIMS AFTER DEADLINE
        if (game.status === 'paused' && game.claimDeadline) {
            const deadline = game.claimDeadline.toDate().getTime();
            if (Date.now() > deadline) {
                console.log("Grace period over. Auto-finalizing game...");
                
                // Move pending claims to confirmed winners
                const pending = game.pendingClaims || [];
                const confirmed = game.confirmedWinners || [];
                const allWinners = [...confirmed, ...pending];

                if (allWinners.length > 0) {
                    const prizePerWinner = (game.prizePool || 0) / allWinners.length;
                    
                    // Transaction for payouts
                    await db.runTransaction(async (transaction) => {
                        for (const winner of allWinners) {
                            const userRef = db.collection('users').doc(winner.userId);
                            const userDoc = await transaction.get(userRef);
                            const currentBalance = userDoc.exists ? (userDoc.data().balance || 0) : 0;
                            transaction.update(userRef, { balance: currentBalance + prizePerWinner });
                        }
                    });

                    await gameDoc.ref.update({
                        status: 'won',
                        winners: allWinners.map(w => w.cardNo.toString()),
                        winnerId: allWinners[0].userId,
                        winningCardNo: allWinners[0].cardNo,
                        endTime: admin.firestore.FieldValue.serverTimestamp(),
                        pendingClaims: [],
                        confirmedWinners: allWinners,
                        claimDeadline: null,
                        statusMessage: "Game Over! Winners have been paid."
                    });

                    // Reset cards
                    const cartelaService = require("./cartelaService");
                    await cartelaService.resetAllRegisteredCards(db);
                } else {
                    // This shouldn't happen if game was paused, but just in case, resume it
                    await gameDoc.ref.update({
                        status: 'active',
                        isPaused: false,
                        claimDeadline: null,
                        statusMessage: "No valid claims. Resuming game..."
                    });
                }
            } else {
                console.log("Game paused. Waiting for grace period to end...");
            }
            
            await new Promise(resolve => setTimeout(resolve, 5000));
            continue;
        }

        if (game.status !== 'active') {
            console.log(`Game is in ${game.status} state. Skipping number draw.`);
            await new Promise(resolve => setTimeout(resolve, 5000));
            continue; // Wait if not active
        }

        const drawnNumbers = game.drawnNumbers || [];
        
        // Generate available numbers (1-75)
        const availableNumbers = Array.from({length: 75}, (_, i) => i + 1)
            .filter(n => !drawnNumbers.includes(n));

        if (availableNumbers.length === 0) {
            console.log("No more numbers available. Finishing game.");
            await gameDoc.ref.update({ 
                status: 'finished',
                endTime: admin.firestore.FieldValue.serverTimestamp()
            });
        } else {
            // Draw random number safely without duplicates
            const randomIndex = Math.floor(Math.random() * availableNumbers.length);
            const newNumber = availableNumbers[randomIndex];
            drawnNumbers.push(newNumber);

            console.log(`Drawing number: ${newNumber}. Total drawn: ${drawnNumbers.length}`);

            const updates = {
                currentNumber: newNumber,
                drawnNumbers: drawnNumbers,
                lastDrawTime: admin.firestore.FieldValue.serverTimestamp()
            };

            // Clear "Waiting for players" message if it's still there
            if (game.statusMessage === "Waiting for players...") {
                updates.statusMessage = "Numbers are being drawn...";
            }

            await gameDoc.ref.update(updates);
        }

        // Wait for 5 seconds
        await new Promise(resolve => setTimeout(resolve, 5000));
    }

    return null;
};
