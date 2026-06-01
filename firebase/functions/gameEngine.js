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
    const loopId = Math.random().toString(36).substring(2, 10);
    console.log(`Starting draw loop with ID: ${loopId}`);


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
                // Reset after 15 seconds for a fast, dynamic game loop!
                if (Date.now() - end >= 15 * 1000) {
                    const counterRef = db.collection('metadata').doc('counters');
                    const counterDoc = await counterRef.get();
                    let sessionNum = 1000;
                    if (counterDoc.exists) {
                        sessionNum = (counterDoc.data().currentSessionId || 1000) + 1;
                    }
                    await counterRef.set({ currentSessionId: sessionNum }, { merge: true });

                    // TTL handles card deletion; no manual batch deletion needed.

                    // Generate pre-shuffled sequence of 75 numbers
                    const drawSequence = Array.from({ length: 75 }, (_, i) => i + 1);
                    for (let i = drawSequence.length - 1; i > 0; i--) {
                        const j = Math.floor(Math.random() * (i + 1));
                        [drawSequence[i], drawSequence[j]] = [drawSequence[j], drawSequence[i]];
                    }

                    await gameDoc.ref.update({
                        status: 'buying',
                        sessionId: sessionNum,
                        startTime: admin.firestore.FieldValue.serverTimestamp(),
                        drawSequence: drawSequence,
                        cardsSold: 0,
                        playersCount: 0,
                        isPaused: false,
                        claimDeadline: null,
                        pendingClaims: [],
                        confirmedWinners: [],
                        winnerId: null,
                        winningCardNo: null,
                        winningCardNumbers: null,
                        winners: [],
                        blockedCardNos: [],
                        statusMessage: "Waiting for players...",
                        currentNumber: null,
                        drawnNumbers: [],
                        lastDrawTime: null,
                        heartbeat: null,
                        loopId: null
                    });

                    // FIX: reset all active cards from the finished session.
                    // TTL (expiresAt) only *deletes* cards after 2 hours — it
                    // does NOT flip status back to 'pending' in time for the
                    // next game. resetAllRegisteredCards does that immediately.
                    const cartelaService = require("./cartelaService");
                    await cartelaService.resetAllRegisteredCards(db);
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
                        const sessionIdStr = (game.sessionId || '').toString();
                        const payoutRef = db.collection('payouts').doc(sessionIdStr);
                        const payoutDoc = await transaction.get(payoutRef);

                        if (payoutDoc.exists) {
                            console.log(`[Payout] Session ${sessionIdStr} already paid (auto-finalize). Skipping.`);
                            return;
                        }

                        for (const winner of allWinners) {
                            const userRef = db.collection('users').doc(winner.userId);
                            transaction.update(userRef, { balance: admin.firestore.FieldValue.increment(prizePerWinner) });
                        }

                        // Write to game history
                        const historyRef = db.collection('game_history').doc();
                        transaction.set(historyRef, {
                            sessionId: game.sessionId || 'N/A',
                            status: 'won',
                            prize: game.prizePool || 0,
                            drawnNumbers: game.drawnNumbers || [],
                            cardsSold: game.cardsSold || 0,
                            winnerId: allWinners[0].userId,
                            winnerName: allWinners[0].phone || 'Player',
                            winningCardNo: allWinners[0].cardNo,
                            createdAt: admin.firestore.FieldValue.serverTimestamp()
                        });

                        // Set the payout document
                        transaction.set(payoutRef, {
                            sessionId: game.sessionId,
                            prizePool: game.prizePool || 0,
                            winnersCount: allWinners.length,
                            prizePerWinner: prizePerWinner,
                            paidAt: admin.firestore.FieldValue.serverTimestamp()
                        });
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
            
            await new Promise(resolve => setTimeout(resolve, 2000));
            continue;
        }

        const pendingClaims = game.pendingClaims || [];
        if (game.status !== 'active' || pendingClaims.length > 0) {
            console.log(`Game is in ${game.status} state with ${pendingClaims.length} pending claims. Skipping number draw.`);
            await new Promise(resolve => setTimeout(resolve, 2000));
            continue; // Wait if not active or if there are pending claims
        }

        // --- DISTRIBUTED LOCK CHECK ---
        const activeHeartbeat = game.heartbeat ? game.heartbeat.toDate().getTime() : 0;
        const activeLoopId = game.loopId || '';

        // If there's an active heartbeat less than 3.5 seconds old, and it is NOT us, exit this loop!
        if (activeHeartbeat && (Date.now() - activeHeartbeat < 3500) && activeLoopId !== loopId) {
            console.log(`[Lock] Another active drawing loop (${activeLoopId}) is running. Exiting loop ${loopId} to prevent duplicate draws.`);
            break;
        }

        const drawnNumbers = game.drawnNumbers || [];
        const drawSequence = game.drawSequence || [];

        // Fallback: if sequence is missing, generate one dynamically on the fly
        if (drawSequence.length === 0) {
            const tempSeq = Array.from({ length: 75 }, (_, i) => i + 1);
            for (let i = tempSeq.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [tempSeq[i], tempSeq[j]] = [tempSeq[j], tempSeq[i]];
            }
            await gameDoc.ref.update({ drawSequence: tempSeq });
            await new Promise(resolve => setTimeout(resolve, 1000));
            continue;
        }

        if (drawnNumbers.length >= 75) {
            console.log("No more numbers available. Finishing game.");
            await gameDoc.ref.update({ 
                status: 'finished',
                endTime: admin.firestore.FieldValue.serverTimestamp()
            });
        } else {
            // Draw next number instantly from pre-shuffled array using O(1) index!
            const nextIndex = drawnNumbers.length;
            const newNumber = drawSequence[nextIndex];
            drawnNumbers.push(newNumber);

            console.log(`Drawing number: ${newNumber}. Total drawn: ${drawnNumbers.length}`);

            const updates = {
                currentNumber: newNumber,
                drawnNumbers: drawnNumbers,
                lastDrawTime: admin.firestore.FieldValue.serverTimestamp(),
                heartbeat: admin.firestore.FieldValue.serverTimestamp(),
                loopId: loopId
            };

            // Clear "Waiting for players" message if it's still there
            if (game.statusMessage === "Waiting for players...") {
                updates.statusMessage = "Numbers are being drawn...";
            }

            await gameDoc.ref.update(updates);

            // Persist draw to single session document (1 write per draw instead of 3)
            const sessionId = game.sessionId;
            if (sessionId) {
                try {
                    const sessionIdStr = sessionId.toString();
                    const sessionDocRef = db.collection('games').doc('live')
                        .collection('sessions').doc(sessionIdStr);

                    await sessionDocRef.set({
                        numbers: admin.firestore.FieldValue.arrayUnion(newNumber),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        sessionId: sessionIdStr
                    }, { merge: true });
                } catch (persistError) {
                    console.error(`Failed to persist draw for session ${sessionId}:`, persistError);
                }
            }
        }

        // Wait for 10 seconds between each number draw
        await new Promise(resolve => setTimeout(resolve, 10000));
    }

    return null;
};

// Immediately triggers the drawing loop when the game status transitions to active
exports.onGameUpdatedHandler = async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (!afterData) return null;

    const beforeStatus = beforeData ? beforeData.status : null;
    const afterStatus = afterData.status;

    if (afterStatus === 'active' && beforeStatus !== 'active') {
        console.log(`Game status transitioned to active (session: ${afterData.sessionId}). Initializing draw loop instantly.`);
        try {
            // Kick off draw loop immediately to prevent the 60-second start lag
            await exports.drawNumberLoopHandler(null);
        } catch (error) {
            console.error("Error executing instant draw loop in onGameUpdatedHandler:", error);
        }
    }

    return null;
};