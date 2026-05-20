const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

async function run() {
    const db = admin.firestore();
    console.log("=== FIRESTORE games/live ===");
    try {
        const doc = await db.collection('games').doc('live').get();
        if (doc.exists) {
            const data = doc.data();
            console.log("Session ID:", data.sessionId);
            console.log("Status:", data.status);
            console.log("Is Paused:", data.isPaused);
            console.log("Winners:", data.winners);
            console.log("Pending Claims Count:", (data.pendingClaims || []).length);
            console.log("Status Message:", data.statusMessage);
            console.log("Current Number:", data.currentNumber);
            console.log("Drawn Numbers Length:", (data.drawnNumbers || []).length);
            console.log("Drawn Numbers:", data.drawnNumbers);
            console.log("Last Draw Time:", data.lastDrawTime ? (data.lastDrawTime.toDate ? data.lastDrawTime.toDate().toISOString() : data.lastDrawTime) : null);
            console.log("Heartbeat:", data.heartbeat ? (data.heartbeat.toDate ? data.heartbeat.toDate().toISOString() : data.heartbeat) : null);
            console.log("Loop ID:", data.loopId);
        } else {
            console.log("games/live document does not exist!");
        }
    } catch (e) {
        console.error("Firestore read failed:", e.message);
    }
    process.exit(0);
}

run();
