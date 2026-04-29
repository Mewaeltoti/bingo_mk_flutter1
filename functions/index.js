const admin = require("firebase-admin");

// Initialize Firebase Admin once
if (!admin.apps.length) {
    admin.initializeApp();
}

const gameEngine = require("./gameEngine");
const cartelaService = require("./cartelaService");
const validationService = require("./validationService");

// Export functions
exports.drawNumberLoop = gameEngine.drawNumberLoop;
exports.buyCard = cartelaService.buyCard;
exports.claimBingo = validationService.claimBingo;
exports.seedPool = cartelaService.seedPool;
exports.registerCard = cartelaService.registerCard;
exports.startNewGame = cartelaService.startNewGame;
exports.cancelGame = cartelaService.cancelGame;
