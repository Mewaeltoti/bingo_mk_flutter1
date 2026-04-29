const functions = require("firebase-functions");
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
        if (game.status !== 'active') {
            await new Promise(resolve => setTimeout(resolve, 5000));
            continue; // Wait if not active
        }

        const drawnNumbers = game.drawnNumbers || [];
        
        // Generate available numbers (1-75)
        const availableNumbers = Array.from({length: 75}, (_, i) => i + 1)
            .filter(n => !drawnNumbers.includes(n));

        if (availableNumbers.length === 0) {
            await gameDoc.ref.update({ status: 'finished' });
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
