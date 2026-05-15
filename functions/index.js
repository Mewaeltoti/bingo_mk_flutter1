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
exports.seedPool = onCall({ cors: true }, (request) => require("./cartelaService").seedPool(request));
exports.cancelGame = onCall({ cors: true }, (request) => require("./cartelaService").cancelGame(request));
exports.removeCard = onCall({ cors: true }, (request) => require("./cartelaService").removeCard(request));

// Game Engine (v1 triggers/schedule)
const gameEngine = require("./gameEngine");
exports.onUserCreated = gameEngine.onUserCreated;
exports.drawNumberLoop = gameEngine.drawNumberLoop;
