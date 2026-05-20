const fs = require('fs');

let content = fs.readFileSync('./functions/validationService.js', 'utf8');

content = content.replace(
    /const { cardId } = request\.data;\s*const userId = request\.auth\.uid;\s*const db = admin\.firestore\(\);\s*const gameRef = db\.collection\('games'\)\.doc\('live'\);\s*const cardRef = db\.collection\('users'\)\.doc\(userId\)\.collection\('cards'\)\.doc\(cardId\);/g,
`    const { cardIds } = request.data;
    const userId = request.auth.uid;
    const db = admin.firestore();
    const gameRef = db.collection('games').doc('live');`
);

content = content.replace(
    /const gameDoc = await transaction\.get\(gameRef\);\s*const cardDoc = await transaction\.get\(cardRef\);\s*if \(\!gameDoc\.exists \|\| \!cardDoc\.exists\) {[\s\S]*?throw new Error\("Game or Card not found\."\);\s*}/g,
`            const gameDoc = await transaction.get(gameRef);
            if (!gameDoc.exists) throw new Error("Game not found.");
            
            const cardDocs = [];
            for (const cId of cardIds) {
                const cRef = db.collection('users').doc(userId).collection('cards').doc(cId);
                const cDoc = await transaction.get(cRef);
                if (cDoc.exists) cardDocs.push({ id: cId, doc: cDoc, ref: cRef });
            }
            if (cardDocs.length === 0) throw new Error("No valid cards found.");`
);

content = content.replace(
    /const drawnNumbers = game\.drawnNumbers \|\| \[\];/g,
`            const rtdbSnap = await admin.database().ref('games/live/drawnNumbers').once('value');
            const drawnNumbers = rtdbSnap.val() || [];`
);

content = content.replace(
    /const cardNumbers = cardDoc\.data\(\)\.numbers;\s*const pattern = \(game\.gamePattern \|\| 'full_house'\)\.toLowerCase\(\)\.replace\(\/\[\\s_\]\/g, ''\);[\s\S]*?transaction\.update\(cardRef, { status: 'claiming' }\);\s*return { success: true, message: "Bingo claimed! Verification in progress\.\.\." };\s*} else {[\s\S]*?missing: validationResult\.missing\s*};\s*}/g,
`            const pattern = (game.gamePattern || 'full_house').toLowerCase().replace(/[\\s_]/g, '');
            
            let validClaimsCount = 0;
            const pendingClaims = game.pendingClaims || [];
            
            const userRef = db.collection('users').doc(userId);
            const userDoc = await transaction.get(userRef);
            const phone = userDoc.exists ? (userDoc.data().phone || '') : '';
            const markedCellsMap = request.data.markedCellsMap || {};

            for (const cardObj of cardDocs) {
                const cardNumbers = cardObj.doc.data().numbers;
                const cardId = cardObj.id;
                
                if (pendingClaims.find(c => c.cardId === cardId)) continue;
                
                const validationResult = validateBingoWithDetails(cardNumbers, drawnNumbers, pattern);
                if (validationResult.isWinner) {
                    validClaimsCount++;
                    const cardNo = cardObj.doc.data().cardNo;
                    pendingClaims.push({
                        cardId,
                        userId,
                        cardNo,
                        phone,
                        numbers: cardNumbers,
                        markedCells: markedCellsMap[cardId] || [],
                        timestamp: new Date().toISOString()
                    });
                    transaction.update(cardObj.ref, { status: 'claiming' });
                }
            }
            
            if (validClaimsCount > 0) {
                const updates = { pendingClaims };
                if (game.status !== 'paused') {
                    updates.status = 'paused';
                    updates.isPaused = true;
                    updates.claimDeadline = admin.firestore.Timestamp.fromMillis(Date.now() + 20000);
                    updates.statusMessage = "BINGO CLAIMED! 20s for other players to claim...";
                }
                transaction.update(gameRef, updates);
                return { success: true, message: validClaimsCount + " Bingo(s) claimed! Verification in progress..." };
            } else {
                return { success: false, message: "Invalid claim(s). Pattern required: " + (game.gamePattern || 'Full House') + "." };
            }`
);

content = content.replace(
    /const drawnNumbers: game\.drawnNumbers \|\| \[\]/g,
    `drawnNumbers: (await admin.database().ref('games/live/drawnNumbers').once('value')).val() || []`
);

content = content.replace(
    /drawnNumbers: game\.drawnNumbers \|\| \[\]/g,
    `drawnNumbers: (await admin.database().ref('games/live/drawnNumbers').once('value')).val() || []`
);

fs.writeFileSync('./functions/validationService.js', content);
console.log('validationService.js patched!');
