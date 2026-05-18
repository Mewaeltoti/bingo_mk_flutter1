const admin = require('firebase-admin');
if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'my-bingo-mk'
    });
}
const db = admin.firestore();

async function checkGame() {
    const gameSnap = await db.collection('games').doc('live').get();
    if (!gameSnap.exists) {
        console.log("No live game document found.");
        return;
    }
    const data = gameSnap.data();
    console.log("Current Game State:");
    console.log(JSON.stringify(data, null, 2));
}

checkGame().catch(console.error);
