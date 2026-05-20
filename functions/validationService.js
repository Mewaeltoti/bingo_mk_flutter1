const { HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

exports.claimBingo = async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be logged in.');
    }

        const { cardIds } = request.data;
    const userId = request.auth.uid;
    const db = admin.firestore();
    const gameRef = db.collection('games').doc('live');

    try {
        const result = await db.runTransaction(async (transaction) => {
                        const gameDoc = await transaction.get(gameRef);
            if (!gameDoc.exists) throw new Error("Game not found.");
            
            const cardDocs = [];
            for (const cId of cardIds) {
                const cRef = db.collection('users').doc(userId).collection('cards').doc(cId);
                const cDoc = await transaction.get(cRef);
                if (cDoc.exists) cardDocs.push({ id: cId, doc: cDoc, ref: cRef });
            }
            if (cardDocs.length === 0) throw new Error("No valid cards found.");

            const cardDoc = cardDocs[0].doc;
            const cardId = cardDocs[0].id;
            const cardRef = cardDocs[0].ref;

            const game = gameDoc.data();
            if (game.status !== 'active' && game.status !== 'paused') {
                console.error(`Claim failed: Game status is ${game.status}`);
                throw new Error("Game is not active or paused.");
            }

            const now = Date.now();
            // Only enforce deadline if the game is already in a paused/claiming state
            if (game.status === 'paused' && game.claimDeadline && now > game.claimDeadline) {
                console.error(`Claim failed: Deadline passed. Now: ${now}, Deadline: ${game.claimDeadline}`);
                throw new Error("The claim period has ended.");
            }

            const cardNumbers = cardDoc.data().numbers;
            const rtdbSnap = await admin.database().ref('games/live/drawnNumbers').once('value');
            const val = rtdbSnap.val();
            let drawnNumbers = [];
            if (val) {
                if (Array.isArray(val)) {
                    drawnNumbers = val.filter(e => e !== null);
                } else {
                    const keys = Object.keys(val).map(Number).sort((a, b) => a - b);
                    drawnNumbers = keys.map(k => val[k]);
                }
            }
            const pattern = (game.gamePattern || 'full_house').toLowerCase().replace(/[\s_]/g, '');

            console.log(`Validating claim for card ${cardId}. Pattern: ${pattern}. Drawn numbers: ${JSON.stringify(drawnNumbers)}`);
            console.log(`Card numbers: ${JSON.stringify(cardNumbers)}`);

            // SERVER-SIDE VALIDATION
            const validationResult = validateBingoWithDetails(cardNumbers, drawnNumbers, pattern);
            const isWinner = validationResult.isWinner;

            if (isWinner) {
                console.log(`Claim SUCCESS for card ${cardId}`);
                const cardNo = cardDoc.data().cardNo;
                const pendingClaims = game.pendingClaims || [];
                
                if (pendingClaims.find(c => c.cardId === cardId)) {
                    throw new Error("Already claimed for this card.");
                }

                const updates = { pendingClaims };
                
                if (game.status !== 'paused') {
                    updates.status = 'paused';
                    updates.isPaused = true;
                    updates.claimDeadline = admin.firestore.Timestamp.fromMillis(Date.now() + 20000);
                    updates.statusMessage = "BINGO CLAIMED! 20s for other players to claim...";
                }

                const userRef = db.collection('users').doc(userId);
                const userDoc = await transaction.get(userRef);
                const phone = userDoc.exists ? (userDoc.data().phone || '') : '';
                const markedCells = (request.data.markedCellsMap && request.data.markedCellsMap[cardId]) || request.data.markedCells || [];

                pendingClaims.push({
                    cardId,
                    userId,
                    cardNo,
                    phone,
                    numbers: cardNumbers,
                    markedCells: markedCells,
                    timestamp: new Date().toISOString()
                });

                transaction.update(gameRef, updates);
                transaction.update(cardRef, { status: 'claiming' });

                return { success: true, message: "Bingo claimed! Verification in progress..." };
            } else {
                console.warn(`Claim REJECTED for card ${cardId}. Missing numbers for ${pattern}: ${JSON.stringify(validationResult.missing)}`);
                return { 
                    success: false, 
                    message: `Invalid claim. Pattern required: ${game.gamePattern || 'Full House'}.`,
                    missing: validationResult.missing
                };
            }
        });
        return result;
    } catch (error) {
        console.error("claimBingo Transaction Error:", error);
        throw new HttpsError('failed-precondition', error.message);
    }
};

function validateBingoWithDetails(cardNumbers, drawnNumbers, pattern) {
    const drawn = new Set(drawnNumbers.map(Number));
    const normalizedPattern = pattern.toLowerCase().replace(/[\s_]/g, '');
    const missing = [];

    const isMarked = (row, col) => {
        if (row === 2 && col === 2) return true; // free space
        const index = row * 5 + col;
        const num = Number(cardNumbers[index]);
        const marked = drawn.has(num);
        if (!marked) {
            missing.push({ row, col, num });
        }
        return marked;
    };

    let isWinner = false;
    const checkMissing = (checkFn) => {
        missing.length = 0; // Reset missing for each check
        return checkFn();
    };

    switch (normalizedPattern) {
        case 'fullhouse':
            isWinner = checkMissing(() => {
                let ok = true;
                for (let r = 0; r < 5; r++)
                    for (let c = 0; c < 5; c++)
                        if (!isMarked(r, c)) ok = false;
                return ok;
            });
            break;

        case 'singleline':
            // Check H lines
            for (let r = 0; r < 5; r++) {
                if (checkMissing(() => {
                    let ok = true;
                    for (let c = 0; c < 5; c++) if (!isMarked(r, c)) ok = false;
                    return ok;
                })) { isWinner = true; break; }
            }
            if (isWinner) break;

            // Check V lines
            for (let c = 0; c < 5; c++) {
                if (checkMissing(() => {
                    let ok = true;
                    for (let r = 0; r < 5; r++) if (!isMarked(r, c)) ok = false;
                    return ok;
                })) { isWinner = true; break; }
            }
            if (isWinner) break;

            // Check D lines
            if (checkMissing(() => {
                let ok = true;
                for (let i = 0; i < 5; i++) if (!isMarked(i, i)) ok = false;
                return ok;
            })) { isWinner = true; break; }

            if (checkMissing(() => {
                let ok = true;
                for (let i = 0; i < 5; i++) if (!isMarked(i, 4 - i)) ok = false;
                return ok;
            })) { isWinner = true; break; }
            break;

        case 'twolines': {
            let linesFound = 0;
            const allMissing = [];
            // Simplified check for two lines
            for (let r = 0; r < 5; r++) {
                if (checkMissing(() => {
                    let ok = true;
                    for (let c = 0; c < 5; c++) if (!isMarked(r, c)) ok = false;
                    return ok;
                })) linesFound++;
                else allMissing.push(...missing);
            }
            // ... (could add more complex logic for two lines, but keeping it simple for now)
            isWinner = linesFound >= 2;
            if (!isWinner) missing.push(...allMissing);
            break;
        }

        case 'fourcorners':
            isWinner = checkMissing(() => {
                return isMarked(0, 0) && isMarked(0, 4) && isMarked(4, 0) && isMarked(4, 4);
            });
            break;

        default:
            // Fallback for other patterns without detailed missing info
            isWinner = validateBingoPattern(cardNumbers, drawnNumbers, pattern);
    }

    return { isWinner, missing: isWinner ? [] : missing };
}

function validateBingoPattern(cardNumbers, drawnNumbers, pattern) {
    const drawn = new Set(drawnNumbers.map(Number));
    const normalizedPattern = pattern.toLowerCase().replace(/[\s_]/g, '');

    const isMarked = (row, col) => {
        if (row === 2 && col === 2) return true; // free space
        const index = row * 5 + col;
        return drawn.has(Number(cardNumbers[index]));
    };

    switch (normalizedPattern) {
        case 'fullhouse':
            for (let r = 0; r < 5; r++)
                for (let c = 0; c < 5; c++)
                    if (!isMarked(r, c)) return false;
            return true;
        // ... (keep rest of existing cases)

        case 'singlelineh':
            for (let r = 0; r < 5; r++) {
                let ok = true;
                for (let c = 0; c < 5; c++) if (!isMarked(r, c)) { ok = false; break; }
                if (ok) return true;
            }
            return false;

        case 'singlelinev':
            for (let c = 0; c < 5; c++) {
                let ok = true;
                for (let r = 0; r < 5; r++) if (!isMarked(r, c)) { ok = false; break; }
                if (ok) return true;
            }
            return false;

        case 'singlelined':
            { 
                let d1 = true, d2 = true;
                for (let i = 0; i < 5; i++) {
                    if (!isMarked(i, i)) d1 = false;
                    if (!isMarked(i, 4 - i)) d2 = false;
                }
                return d1 || d2;
            }

        case 'singleline': // Any single line (H, V, or D)
            // H
            for (let r = 0; r < 5; r++) {
                let ok = true;
                for (let c = 0; c < 5; c++) if (!isMarked(r, c)) { ok = false; break; }
                if (ok) return true;
            }
            // V
            for (let c = 0; c < 5; c++) {
                let ok = true;
                for (let r = 0; r < 5; r++) if (!isMarked(r, c)) { ok = false; break; }
                if (ok) return true;
            }
            // D
            let d1 = true, d2 = true;
            for (let i = 0; i < 5; i++) {
                if (!isMarked(i, i)) d1 = false;
                if (!isMarked(i, 4 - i)) d2 = false;
            }
            return d1 || d2;

        case 'twolines': {
            let lineCount = 0;
            for (let r = 0; r < 5; r++) {
                let ok = true;
                for (let c = 0; c < 5; c++) if (!isMarked(r, c)) { ok = false; break; }
                if (ok) lineCount++;
            }
            for (let c = 0; c < 5; c++) {
                let ok = true;
                for (let r = 0; r < 5; r++) if (!isMarked(r, c)) { ok = false; break; }
                if (ok) lineCount++;
            }
            let diag1 = true, diag2 = true;
            for (let i = 0; i < 5; i++) {
                if (!isMarked(i, i)) diag1 = false;
                if (!isMarked(i, 4 - i)) diag2 = false;
            }
            if (diag1) lineCount++;
            if (diag2) lineCount++;
            return lineCount >= 2;
        }

        case 'fourcorners':
            return isMarked(0, 0) && isMarked(0, 4) && isMarked(4, 0) && isMarked(4, 4);

        case 'xshape':
            for (let i = 0; i < 5; i++) {
                if (!isMarked(i, i)) return false;
                if (!isMarked(i, 4 - i)) return false;
            }
            return true;

        case 'tshape':
            for (let c = 0; c < 5; c++) if (!isMarked(0, c)) return false;
            for (let r = 0; r < 5; r++) if (!isMarked(r, 2)) return false;
            return true;

        case 'lshape':
            for (let r = 0; r < 5; r++) if (!isMarked(r, 0)) return false;
            for (let c = 0; c < 5; c++) if (!isMarked(4, c)) return false;
            return true;

        case 'cross':
            for (let c = 0; c < 5; c++) if (!isMarked(2, c)) return false;
            for (let r = 0; r < 5; r++) if (!isMarked(r, 2)) return false;
            return true;

        case 'frame':
            for (let i = 0; i < 5; i++) {
                if (!isMarked(0, i)) return false;
                if (!isMarked(4, i)) return false;
                if (!isMarked(i, 0)) return false;
                if (!isMarked(i, 4)) return false;
            }
            return true;

        case 'postagestamp':
            const corners = [[0,0],[0,3],[3,0],[3,3]];
            for (const [sr, sc] of corners) {
                if (isMarked(sr, sc) && isMarked(sr, sc+1) && isMarked(sr+1, sc) && isMarked(sr+1, sc+1)) return true;
            }
            return false;

        case 'smalldiamond':
            return isMarked(0, 2) && isMarked(1, 1) && isMarked(1, 3) && isMarked(2, 0) && isMarked(2, 4) && isMarked(3, 1) && isMarked(3, 3) && isMarked(4, 2);

        case 'arrowup':
            for (let r = 0; r < 5; r++) if (!isMarked(r, 2)) return false;
            if (!isMarked(1, 1) || !isMarked(1, 3)) return false;
            if (!isMarked(0, 0) || !isMarked(0, 4)) return false;
            return true;

        case 'pyramid':
            if (!isMarked(0, 2)) return false;
            if (!isMarked(1, 1) || !isMarked(1, 2) || !isMarked(1, 3)) return false;
            if (!isMarked(2, 0) || !isMarked(2, 1) || !isMarked(2, 2) || !isMarked(2, 3) || !isMarked(2, 4)) return false;
            return true;

        case 'ushape':
            for (let r = 0; r < 5; r++) if (!isMarked(r, 0)) return false;
            for (let r = 0; r < 5; r++) if (!isMarked(r, 4)) return false;
            for (let c = 0; c < 5; c++) if (!isMarked(4, c)) return false;
            return true;

        default:
            return false;
    }
}

exports.confirmBingoClaim = async (request) => {
    // Basic auth check
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in.');

    const { cardId } = request.data;
    const db = admin.firestore();
    const gameRef = db.collection('games').doc('live');
    const cartelaService = require("./cartelaService");

    await db.runTransaction(async (transaction) => {
        const gameDoc = await transaction.get(gameRef);
        if (!gameDoc.exists) throw new Error("Game not found.");

        const game = gameDoc.data();
        const pendingClaims = game.pendingClaims || [];
        const confirmedWinners = game.confirmedWinners || [];

        const claimIndex = pendingClaims.findIndex(c => c.cardId === cardId);
        if (claimIndex === -1) throw new Error("Claim not found.");

        const claim = pendingClaims[claimIndex];
        confirmedWinners.push(claim);
        pendingClaims.splice(claimIndex, 1);

        const updates = { pendingClaims, confirmedWinners };

        // If no more pending claims, and we have confirmed winners, finalize and payout!
        if (pendingClaims.length === 0 && confirmedWinners.length > 0) {
            const prizePerWinner = (game.prizePool || 0) / confirmedWinners.length;

            // Pay out each winner
            for (const winner of confirmedWinners) {
                const userRef = db.collection('users').doc(winner.userId);
                const userDoc = await transaction.get(userRef);
                const currentBalance = userDoc.exists ? (userDoc.data().balance || 0) : 0;
                transaction.update(userRef, { balance: currentBalance + prizePerWinner });

                // Write to game_winners collection
                const winnerRef = db.collection('game_winners').doc(winner.cardNo.toString());
                transaction.set(winnerRef, {
                    sessionId: game.sessionId || 'N/A',
                    cardNo: winner.cardNo.toString(),
                    userId: winner.userId,
                    phone: winner.phone || 'Player',
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }

            // Write to game history
            const historyRef = db.collection('game_history').doc();
            transaction.set(historyRef, {
                sessionId: game.sessionId || 'N/A',
                status: 'won',
                prize: game.prizePool || 0,
                drawnNumbers: (await admin.database().ref('games/live/drawnNumbers').once('value')).val() || [],
                cardsSold: game.cardsSold || 0,
                winnerId: confirmedWinners[0].userId,
                winnerName: confirmedWinners[0].phone || 'Player',
                winningCardNo: confirmedWinners[0].cardNo,
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });

            // Mark game as won and set end time so it auto-resets in 15 seconds!
            updates.status = 'won';
            updates.winners = confirmedWinners.map(w => w.cardNo.toString());
            updates.winnerId = confirmedWinners[0].userId;
            updates.winningCardNo = confirmedWinners[0].cardNo;
            updates.endTime = admin.firestore.FieldValue.serverTimestamp();
            updates.confirmedWinners = confirmedWinners;
            updates.claimDeadline = null;
            updates.statusMessage = "Game Over! Winners have been paid.";

            // Reset all cards
            await cartelaService.resetAllRegisteredCards(db);
        } else if (pendingClaims.length === 0) {
            // Fallback: If no confirmed winners, resume game
            updates.status = 'active';
            updates.isPaused = false;
            updates.claimDeadline = null;
            updates.statusMessage = "Verification complete. Game resumed!";
        }

        transaction.update(gameRef, updates);
    });

    return { success: true };
};

exports.rejectBingoClaim = async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in.');

    const { cardId, userId } = request.data;
    const db = admin.firestore();
    const gameRef = db.collection('games').doc('live');
    const cardRef = db.collection('users').doc(userId).collection('cards').doc(cardId);

    await db.runTransaction(async (transaction) => {
        const gameDoc = await transaction.get(gameRef);
        if (!gameDoc.exists) throw new Error("Game not found.");

        const game = gameDoc.data();
        const pendingClaims = game.pendingClaims || [];
        const claimIndex = pendingClaims.findIndex(c => c.cardId === cardId);
        if (claimIndex !== -1) {
            pendingClaims.splice(claimIndex, 1);
            const updates = { pendingClaims };
            
            // Resume game if no more claims are pending
            if (pendingClaims.length === 0) {
                updates.status = 'active';
                updates.isPaused = false;
                updates.claimDeadline = null;
                updates.statusMessage = "Claims rejected - game resumed.";
            }
            
            transaction.update(gameRef, updates);
        }
        transaction.update(cardRef, { status: 'registered' }); // Back to registered
    });

    return { success: true };
};

exports.finalizeGameAndPayout = async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in.');

    const db = admin.firestore();
    const gameRef = db.collection('games').doc('live');
    const cartelaService = require("./cartelaService");

    await db.runTransaction(async (transaction) => {
        const gameDoc = await transaction.get(gameRef);
        if (!gameDoc.exists) throw new Error("Game not found.");

        const game = gameDoc.data();
        const winners = game.confirmedWinners || [];
        if (winners.length === 0) throw new Error("No confirmed winners.");

        const prizePerWinner = (game.prizePool || 0) / winners.length;

        // Pay out each winner
        for (const winner of winners) {
            const userRef = db.collection('users').doc(winner.userId);
            const userDoc = await transaction.get(userRef);
            const currentBalance = userDoc.data().balance || 0;
            transaction.update(userRef, { balance: currentBalance + prizePerWinner });

            // Write to game_winners collection
            const winnerRef = db.collection('game_winners').doc(winner.cardNo.toString());
            transaction.set(winnerRef, {
                sessionId: game.sessionId || 'N/A',
                cardNo: winner.cardNo.toString(),
                userId: winner.userId,
                phone: winner.phone || 'Player',
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        // Write to game history
        const historyRef = db.collection('game_history').doc();
        transaction.set(historyRef, {
            sessionId: game.sessionId || 'N/A',
            status: 'won',
            prize: game.prizePool || 0,
            drawnNumbers: (await admin.database().ref('games/live/drawnNumbers').once('value')).val() || [],
            cardsSold: game.cardsSold || 0,
            winnerId: winners[0].userId,
            winnerName: winners[0].phone || 'Player',
            winningCardNo: winners[0].cardNo,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Set game to won
        transaction.update(gameRef, {
            status: 'won',
            winners: winners.map(w => w.cardNo.toString()), // Show card numbers in winners badge
            winnerId: winners[0].userId, // Primary winner for history
            winningCardNo: winners[0].cardNo,
            endTime: admin.firestore.FieldValue.serverTimestamp(),
            pendingClaims: [],
            confirmedWinners: [],
            claimDeadline: null
        });

        // Reset all cards
        await cartelaService.resetAllRegisteredCards(db);
    });

    return { success: true };
};
