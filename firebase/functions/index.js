const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

const { onCall } = require("firebase-functions/v2/https");

// Lazy loading handlers to avoid deployment timeouts during initialization
exports.claimBingo = onCall({ cors: true }, (request) => require("./validationService").claimBingo(request));
exports.confirmBingoClaim = onCall({ cors: true }, (request) => require("./validationService").confirmBingoClaim(request));
exports.rejectBingoClaim = onCall({ cors: true }, (request) => require("./validationService").rejectBingoClaim(request));
exports.finalizeGameAndPayout = onCall({ cors: true }, (request) => require("./validationService").finalizeGameAndPayout(request));

exports.buyCard = onCall({ cors: true }, (request) => require("./cartelaService").buyCard(request));
exports.registerCard = onCall({ cors: true }, (request) => require("./cartelaService").registerCard(request));
exports.startNewGame = onCall({ cors: true }, (request) => require("./cartelaService").startNewGame(request));
exports.seedPool = onCall({ cors: true, timeoutSeconds: 540 }, (request) => require("./cartelaService").seedPool(request));
exports.cancelGame = onCall({ cors: true }, (request) => require("./cartelaService").cancelGame(request));
exports.removeCard = onCall({ cors: true }, (request) => require("./cartelaService").removeCard(request));

// Atomic withdrawal with balance reservation (double-spend prevention)
exports.createWithdrawal = onCall({ cors: true }, (request) => require("../src/createWithdrawal").createWithdrawal(request));

// Game Engine (v1 triggers/schedule - lazy loaded)
const functions = require("firebase-functions/v1");

exports.onUserCreated = functions.auth.user().onCreate((user) => 
    require("./gameEngine").onUserCreatedHandler(user)
);

exports.drawNumberLoop = functions.pubsub.schedule('every 1 minutes').onRun((context) => 
    require("./gameEngine").drawNumberLoopHandler(context)
);

exports.onGameUpdated = functions.runWith({
    timeoutSeconds: 540,
    memory: '256MB'
}).firestore
    .document('games/live')
    .onUpdate((change, context) => 
        require("./gameEngine").onGameUpdatedHandler(change, context)
    );


// Auto-Reconciliation Services (Lazy Loaded)
const { onRequest } = require("firebase-functions/v2/https");

exports.smsWebhook = onRequest({ cors: true }, (req, res) => 
    require("./reconciliationService").smsWebhook(req, res)
);

exports.onDepositCreated = functions.firestore
    .document('users/{userId}/deposits/{depositId}')
    .onCreate((snap, context) => 
        require("./reconciliationService").onDepositCreatedHandler(snap, context)
    );

exports.onWithdrawalCreated = functions.firestore
    .document('users/{userId}/withdrawals/{withdrawId}')
    .onCreate((snap, context) => 
        require("./reconciliationService").onWithdrawalCreatedHandler(snap, context)
    );

exports.onWithdrawalUpdated = functions.firestore
    .document('users/{userId}/withdrawals/{withdrawId}')
    .onUpdate((change, context) => 
        require("./reconciliationService").onWithdrawalUpdatedHandler(change, context)
    );

exports.blockCard = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new Error('unauthenticated');
  }

  const { userId, cardId } = request.data;

  if (request.auth.uid !== userId) {
    throw new Error('permission-denied');
  }

  await admin.firestore()
    .collection('users').doc(userId)
    .collection('cards').doc(cardId)
    .update({ 
      status: 'blocked',
      blocked: true,                                           // ← add this
      blockedAt: admin.firestore.FieldValue.serverTimestamp()
    });

  return { success: true };
});