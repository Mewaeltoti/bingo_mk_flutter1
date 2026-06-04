const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

const { onCall, onRequest } = require("firebase-functions/v2/https");
const functions = require("firebase-functions/v1");

// ─── Game / Bingo logic ───────────────────────────────────────────────────────
exports.claimBingo         = onCall({ cors: true }, (req) => require("./validationService").claimBingo(req));
exports.confirmBingoClaim  = onCall({ cors: true }, (req) => require("./validationService").confirmBingoClaim(req));
exports.rejectBingoClaim   = onCall({ cors: true }, (req) => require("./validationService").rejectBingoClaim(req));
exports.finalizeGameAndPayout = onCall({ cors: true }, (req) => require("./validationService").finalizeGameAndPayout(req));

exports.buyCard    = onCall({ cors: true }, (req) => require("./cartelaService").buyCard(req));
exports.registerCard = onCall({ cors: true }, (req) => require("./cartelaService").registerCard(req));
exports.startNewGame = onCall({ cors: true }, (req) => require("./cartelaService").startNewGame(req));
exports.seedPool   = onCall({ cors: true, timeoutSeconds: 540 }, (req) => require("./cartelaService").seedPool(req));
exports.cancelGame = onCall({ cors: true }, (req) => require("./cartelaService").cancelGame(req));
exports.removeCard = onCall({ cors: true }, (req) => require("./cartelaService").removeCard(req));

exports.blockCard = onCall({ cors: true }, async (request) => {
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
// The old createWithdrawal CF has been removed.
// Withdrawals are written directly to Firestore by the Flutter client (pending).
// The admin calls this function to approve — it atomically deducts the balance
// and marks the withdrawal approved. There is no reject flow; the admin either
// approves or deletes the record from the admin panel.
exports.approveWithdrawal = onCall({ cors: true }, (req) =>
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
exports.smsWebhook = onRequest({ cors: true }, (req, res) =>
    require("./reconciliationService").smsWebhook(req, res)
);

exports.onDepositCreated = functions.firestore
    .document("users/{userId}/deposits/{depositId}")
    .onCreate((snap, context) =>
        require("./reconciliationService").onDepositCreatedHandler(snap, context)
    );

// ─── Withdrawal trigger (no-op — balance is NOT reserved on submit) ───────────
// Kept as a stub so Firestore trigger infrastructure remains in place,
// but it does nothing. Balance deduction only happens in approveWithdrawal().
exports.onWithdrawalCreated = functions.firestore
    .document("users/{userId}/withdrawals/{withdrawId}")
    .onCreate((snap, context) =>
        require("./reconciliationService").onWithdrawalCreatedHandler(snap, context)
    );

// onWithdrawalUpdated has been intentionally REMOVED.
// Previously it refunded balance on rejection — that caused the double-credit bug.
// There is no rejection flow anymore, so there is nothing to refund.
