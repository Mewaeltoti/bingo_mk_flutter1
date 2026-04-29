const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

exports.claimBingo = onCall({ cors: true }, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be logged in.');
    }

    const { cardId } = request.data;
    const userId = request.auth.uid;
    const db = admin.firestore();

    const gameRef = db.collection('games').doc('live');
    const cardRef = db.collection('users').doc(userId).collection('cards').doc(cardId);

    try {
        const result = await db.runTransaction(async (transaction) => {
            const gameDoc = await transaction.get(gameRef);
            const cardDoc = await transaction.get(cardRef);

            if (!gameDoc.exists || !cardDoc.exists) {
                throw new Error("Game or Card not found.");
            }

            const game = gameDoc.data();
            if (game.status !== 'active') {
                throw new Error("Game is not active.");
            }

            const cardNumbers = cardDoc.data().numbers;
            const drawnNumbers = game.drawnNumbers || [];

            // SERVER-SIDE VALIDATION
            const isWinner = validateBingoPattern(cardNumbers, drawnNumbers, game.gamePattern);

            if (isWinner) {
                const historyRef = db.collection('game_history').doc();
                transaction.set(historyRef, {
                    sessionId: game.sessionId || 'N/A',
                    winnerId: userId,
                    prize: game.prizePool || 0,
                    drawnNumbers: drawnNumbers,
                    gamePattern: game.gamePattern,
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });

                transaction.update(gameRef, {
                    status: 'won',
                    winnerId: userId,
                    endTime: admin.firestore.FieldValue.serverTimestamp()
                });
                return { success: true, message: "Bingo confirmed!" };
            } else {
                return { success: false, message: "Invalid claim." };
            }
        });
        return result;
    } catch (error) {
        throw new HttpsError('failed-precondition', error.message);
    }
});

// cardNumbers: flat array of 25 numbers. Index 12 = free space (value 0).
function validateBingoPattern(cardNumbers, drawnNumbers, pattern) {
    const drawn = new Set(drawnNumbers.map(Number));

    const isMarked = (row, col) => {
        if (row === 2 && col === 2) return true; // free space
        const index = row * 5 + col;
        return drawn.has(Number(cardNumbers[index]));
    };

    switch (pattern) {
        case 'Full House':
        case 'full_house':
            for (let r = 0; r < 5; r++)
                for (let c = 0; c < 5; c++)
                    if (!isMarked(r, c)) return false;
            return true;

        case 'Single Line H':
            for (let r = 0; r < 5; r++) {
                let ok = true;
                for (let c = 0; c < 5; c++) if (!isMarked(r, c)) { ok = false; break; }
                if (ok) return true;
            }
            return false;

        case 'Single Line V':
            for (let c = 0; c < 5; c++) {
                let ok = true;
                for (let r = 0; r < 5; r++) if (!isMarked(r, c)) { ok = false; break; }
                if (ok) return true;
            }
            return false;

        case 'Single Line D':
            { 
                let d1 = true, d2 = true;
                for (let i = 0; i < 5; i++) {
                    if (!isMarked(i, i)) d1 = false;
                    if (!isMarked(i, 4 - i)) d2 = false;
                }
                return d1 || d2;
            }

        case 'single_line': // Any single line (H, V, or D)
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

        case 'Two Lines': {
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

        case 'Four Corners':
        case 'four_corners':
            return isMarked(0, 0) && isMarked(0, 4) && isMarked(4, 0) && isMarked(4, 4);

        case 'X Shape':
            for (let i = 0; i < 5; i++) {
                if (!isMarked(i, i)) return false;
                if (!isMarked(i, 4 - i)) return false;
            }
            return true;

        case 'T Shape':
            for (let c = 0; c < 5; c++) if (!isMarked(0, c)) return false;
            for (let r = 0; r < 5; r++) if (!isMarked(r, 2)) return false;
            return true;

        case 'L Shape':
            for (let r = 0; r < 5; r++) if (!isMarked(r, 0)) return false;
            for (let c = 0; c < 5; c++) if (!isMarked(4, c)) return false;
            return true;

        case 'Cross':
            for (let c = 0; c < 5; c++) if (!isMarked(2, c)) return false;
            for (let r = 0; r < 5; r++) if (!isMarked(r, 2)) return false;
            return true;

        case 'Frame':
            for (let i = 0; i < 5; i++) {
                if (!isMarked(0, i)) return false;
                if (!isMarked(4, i)) return false;
                if (!isMarked(i, 0)) return false;
                if (!isMarked(i, 4)) return false;
            }
            return true;

        case 'Postage Stamp':
            const corners = [[0,0],[0,3],[3,0],[3,3]];
            for (const [sr, sc] of corners) {
                if (isMarked(sr, sc) && isMarked(sr, sc+1) && isMarked(sr+1, sc) && isMarked(sr+1, sc+1)) return true;
            }
            return false;

        case 'Small Diamond':
            return isMarked(0, 2) && isMarked(1, 1) && isMarked(1, 3) && isMarked(2, 0) && isMarked(2, 4) && isMarked(3, 1) && isMarked(3, 3) && isMarked(4, 2);

        case 'Arrow Up':
            for (let r = 0; r < 5; r++) if (!isMarked(r, 2)) return false;
            if (!isMarked(1, 1) || !isMarked(1, 3)) return false;
            if (!isMarked(0, 0) || !isMarked(0, 4)) return false;
            return true;

        case 'Pyramid':
            if (!isMarked(0, 2)) return false;
            if (!isMarked(1, 1) || !isMarked(1, 2) || !isMarked(1, 3)) return false;
            if (!isMarked(2, 0) || !isMarked(2, 1) || !isMarked(2, 2) || !isMarked(2, 3) || !isMarked(2, 4)) return false;
            return true;

        case 'U Shape':
            for (let r = 0; r < 5; r++) if (!isMarked(r, 0)) return false;
            for (let r = 0; r < 5; r++) if (!isMarked(r, 4)) return false;
            for (let c = 0; c < 5; c++) if (!isMarked(4, c)) return false;
            return true;

        default:
            return false;
    }
}
