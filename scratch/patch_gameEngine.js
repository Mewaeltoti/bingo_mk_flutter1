const fs = require('fs');
let content = fs.readFileSync('./functions/gameEngine.js', 'utf8');

// Replace Firestore game.drawnNumbers read
content = content.replace(
    /const drawnNumbers = game\.drawnNumbers \|\| \[\];/g,
`        const rtdbSnap = await admin.database().ref('games/live/drawnNumbers').once('value');
        const drawnNumbers = rtdbSnap.val() || [];`
);

// Replace Firestore updates that include drawnNumbers
content = content.replace(
    /const updates = \{\s*currentNumber: newNumber,\s*drawnNumbers: drawnNumbers,\s*lastDrawTime: admin\.firestore\.FieldValue\.serverTimestamp\(\)\s*\};/g,
`            const updates = {};
            await admin.database().ref('games/live').update({
                currentNumber: newNumber,
                drawnNumbers: drawnNumbers,
                lastDrawTime: admin.database.ServerValue.TIMESTAMP
            });`
);

// remove drawnNumbers: [], from startNewGame
content = content.replace(
    /drawnNumbers: \[\],\s*/g,
    "" 
);

// remove currentNumber: null, from startNewGame
content = content.replace(
    /currentNumber: null,\s*/g,
    ""
);

// remove lastDrawTime: null, from startNewGame
content = content.replace(
    /lastDrawTime: null,\s*/g,
    ""
);

// In startNewGame we should also wipe RTDB.
content = content.replace(
    /await gameRef\.set\(newGameData\);/g,
`    await gameRef.set(newGameData);
    await admin.database().ref('games/live').set({ drawnNumbers: [], currentNumber: null });`
);

// In cancelGame we should also wipe RTDB.
content = content.replace(
    /await db\.collection\('games'\)\.doc\('live'\)\.update\(\{[\s\S]*?status: 'cancelled'[\s\S]*?\}\);/g,
`$&
        await admin.database().ref('games/live').set({ drawnNumbers: [], currentNumber: null });`
);

fs.writeFileSync('./functions/gameEngine.js', content);
console.log('gameEngine.js patched!');
