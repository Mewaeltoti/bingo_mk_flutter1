const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

// Initialize Firebase Admin
if (!admin.apps.length) {
    const serviceAccountPath = path.join(__dirname, 'bingo-be44c-firebase-adminsdk-fbsvc-b1641b95e4.json');
    try {
        if (fs.existsSync(serviceAccountPath)) {
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccountPath)
            });
            console.log("Firebase Admin initialized using service account JSON.");
        } else {
            admin.initializeApp();
            console.log("Firebase Admin initialized using environment default credentials.");
        }
    } catch (e) {
        admin.initializeApp();
        console.warn("Firebase Admin fallback initialization:", e.message);
    }
}

const db = admin.firestore();
const gameEngine = require("./gameEngine");

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

// Socket.IO Authentication Middleware using Firebase Admin SDK
io.use(async (socket, next) => {
    try {
        const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization;
        if (!token) {
            console.warn("Authentication rejected: No token provided.");
            return next(new Error("Authentication error: Token is required."));
        }

        // Support standard Bearer authorization header format
        let idToken = token;
        if (token.startsWith("Bearer ")) {
            idToken = token.slice(7);
        }

        const decodedToken = await admin.auth().verifyIdToken(idToken);
        socket.user = decodedToken;
        console.log(`Socket authenticated successfully for UID: ${decodedToken.uid}`);
        return next();
    } catch (error) {
        console.error("Socket authentication failed:", error.message);
        return next(new Error(`Authentication error: ${error.message}`));
    }
});

// Socket.IO Events
io.on("connection", (socket) => {
    console.log(`New Socket.IO client connected: ${socket.id} (UID: ${socket.user.uid})`);

    socket.on("join_game", (room = "live") => {
        socket.join(room);
        console.log(`Socket ${socket.id} joined room: ${room}`);
        socket.emit("joined", { room });
    });

    socket.on("disconnect", () => {
        console.log(`Client disconnected: ${socket.id}`);
    });
});

// Express status endpoint for manual verification
app.get("/status", async (req, res) => {
    try {
        const gameSnap = await db.collection("games").doc("live").get();
        if (!gameSnap.exists) {
            return res.status(404).json({ error: "Live game document not found" });
        }
        res.json({
            status: "running",
            game: gameSnap.data()
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Engine Recovery and Draw Loop Resumption
async function recoverEngine() {
    console.log("\n=============================================");
    console.log("Bingo Engine Recovery System Initiated");
    console.log("=============================================");

    try {
        const gameSnap = await db.collection("games").doc("live").get();
        if (!gameSnap.exists) {
            console.log("No live game document (games/live) found. Recovery skipped.");
            return;
        }

        const game = gameSnap.data();
        const sessionId = game.sessionId;

        if (!sessionId) {
            console.log("No active sessionId in games/live. Recovery skipped.");
            return;
        }

        console.log(`Checking recovery status for Session: ${sessionId}`);
        console.log(`Current DB status: ${game.status}`);

        if (game.status === "active") {
            console.log(`Replaying Firestore events for Session ${sessionId} to reconstruct in-memory state...`);
            
            const eventsSnap = await db.collection("games")
                .doc(sessionId.toString())
                .collection("events")
                .orderBy("timestamp", "asc")
                .get();

            const reconstructedDrawnNumbers = [];
            eventsSnap.forEach((doc) => {
                const event = doc.data();
                if (event.type === "NUMBER_DRAWN" && typeof event.number === "number") {
                    reconstructedDrawnNumbers.push(event.number);
                }
            });

            console.log(`SUCCESS: Reconstructed in-memory state!`);
            console.log(`Total numbers replayed: ${reconstructedDrawnNumbers.length}`);
            console.log(`Drawn numbers: [${reconstructedDrawnNumbers.join(", ")}]`);

            // Verify with snapshot if we need to
            const snapshotRef = db.collection("games").doc(sessionId.toString()).collection("state").doc("state");
            const snapshotDoc = await snapshotRef.get();
            if (snapshotDoc.exists) {
                console.log(`Firestore snapshot states: status=${snapshotDoc.data().status}, drawnCount=${snapshotDoc.data().drawnCount}`);
            }

            console.log("Resuming drawing loop...");
            // Run drawing loop asynchronously so it doesn't block server listening
            gameEngine.drawNumberLoopHandler(null).catch((err) => {
                console.error("Error in draw loop execution:", err);
            });
        } else {
            console.log(`Game is in '${game.status}' state. No active draw loop to resume.`);
        }
    } catch (error) {
        console.error("Engine recovery failed with error:", error);
    }
    console.log("=============================================\n");
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, async () => {
    console.log(`Socket.IO Server is listening on port ${PORT}`);
    await recoverEngine();
});
