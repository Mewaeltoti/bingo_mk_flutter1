console.time("admin");
const admin = require("firebase-admin");
console.timeEnd("admin");

console.time("gameEngine");
require("./gameEngine");
console.timeEnd("gameEngine");

console.time("cartelaService");
require("./cartelaService");
console.timeEnd("cartelaService");

console.time("validationService");
require("./validationService");
console.timeEnd("validationService");
