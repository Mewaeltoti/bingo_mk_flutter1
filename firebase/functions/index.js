const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

const { onCall, onRequest } = require("firebase-functions/v2/https");
const functions = require("firebase-functions/v1");

// ─── CORS origin list ─────────────────────────────────────────────────────────
// v2 onCall with an explicit origins array correctly handles OPTIONS preflight.
// "cors: true" on firebase-functions@7.x does NOT — it fails to set the
// Access-Control-Allow-Origin header on preflight responses from browsers.
const ALLOWED_ORIGINS = [
    "https://bingo-admin-web.vercel.app",
    "http://localhost:5173",   // local dev
    "http://localhost:4173",   // vite preview
];

const corsOpts = { cors: ALLOWED_ORIGINS };

// ─── Game / Bingo logic ───────────────────────────────────────────────────────
exports.claimBingo            = onCall(corsOpts, (req) => require("./validationService").claimBingo(req));
exports.confirmBingoClaim     = onCall(corsOpts, (req) => require("./validationService").confirmBingoClaim(req));
exports.rejectBingoClaim      = onCall(corsOpts, (req) => require("./validationService").rejectBingoClaim(req));
exports.finalizeGameAndPayout = onCall(corsOpts, (req) => require("./validationService").finalizeGameAndPayout(req));

exports.buyCard      = onCall(corsOpts, (req) => require("./cartelaService").buyCard(req));
exports.registerCard = onCall(corsOpts, (req) => require("./cartelaService").registerCard(req));
exports.startNewGame = onCall(corsOpts, (req) => require("./cartelaService").startNewGame(req));
exports.seedPool     = onCall({ ...corsOpts, timeoutSeconds: 540 }, (req) => require("./cartelaService").seedPool(req));
exports.cancelGame   = onCall(corsOpts, (req) => require("./cartelaService").cancelGame(req));
exports.removeCard   = onCall(corsOpts, (req) => require("./cartelaService").removeCard(req));

exports.blockCard = onCall(corsOpts, async (request) => {
    if (!request.auth) throw new Error("unauthenticated");
    const { userId, cardId } = request.data;
    if (request.auth.uid !== userId) throw new Error("permission-denied");
    await admin.firestore()
        .collection("users").doc(userId)
        .collection("cards").doc(cardId)
        .update({
            status: "blocked",
            blocked: true,
            blockedAt: admin.firestore.FieldValue.serverTimestamp()
        });
    return { success: true };
});

// ─── Withdrawal approval (admin only) ────────────────────────────────────────
exports.approveWithdrawal = onCall(corsOpts, (req) =>
    require("./reconciliationService").approveWithdrawalHandler(req)
);

// ─── Game engine (v1 triggers) ────────────────────────────────────────────────
exports.onUserCreated = functions.auth.user().onCreate((user) =>
    require("./gameEngine").onUserCreatedHandler(user)
);

exports.drawNumberLoop = functions.pubsub.schedule("every 1 minutes").onRun((context) =>
    require("./gameEngine").drawNumberLoopHandler(context)
);

exports.onGameUpdated = functions.runWith({
    timeoutSeconds: 540,
    memory: "256MB"
}).firestore
    .document("games/live")
    .onUpdate((change, context) =>
        require("./gameEngine").onGameUpdatedHandler(change, context)
    );

// ─── Deposit auto-reconciliation ──────────────────────────────────────────────
exports.smsWebhook = onRequest({ cors: ALLOWED_ORIGINS }, (req, res) =>
    require("./reconciliationService").smsWebhook(req, res)
);

exports.onDepositCreated = functions.firestore
    .document("users/{userId}/deposits/{depositId}")
    .onCreate((snap, context) =>
        require("./reconciliationService").onDepositCreatedHandler(snap, context)
    );

exports.onWithdrawalCreated = functions.firestore
    .document("users/{userId}/withdrawals/{withdrawId}")
    .onCreate((snap, context) =>
        require("./reconciliationService").onWithdrawalCreatedHandler(snap, context)
    );