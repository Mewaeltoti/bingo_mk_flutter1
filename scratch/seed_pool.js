const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

console.log("Starting local high-speed pool seeder...");

// Initialize Firebase Admin using the service account key
const serviceAccountPath = path.join(__dirname, '..', 'bingo-be44c-firebase-adminsdk-fbsvc-b1641b95e4.json');

if (!fs.existsSync(serviceAccountPath)) {
    console.error(`ERROR: Service account key not found at: ${serviceAccountPath}`);
    process.exit(1);
}

admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath)
});

const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

const dataPath = path.join(__dirname, "..", "firebase", "functions", "data.json");
if (!fs.existsSync(dataPath)) {
    console.error(`ERROR: data.json not found at: ${dataPath}`);
    process.exit(1);
}

console.log("Loading data.json... (This may take a moment due to its 4.3MB size)");
const rawData = fs.readFileSync(dataPath, "utf8");
const allCards = JSON.parse(rawData);
console.log(`Successfully loaded ${allCards.length} cards from data.json!`);

async function seedPool() {
    const poolRef = db.collection("cartelas_pool");
    let batch = db.batch();
    let processed = 0;
    
    console.log("\nSeeding cartelas_pool in Firestore...");
    
    for (const card of allCards) {
        const originalNumbers = card.bingo_numbers;
        const numbers25 = [...originalNumbers];

        // Standardize 24-number format to 25-number format by putting the free space (0) at index 12
        if (numbers25.length === 24) {
            numbers25.splice(12, 0, 0);
        }

        const cardDoc = poolRef.doc(card.cartela_no.toString());
        batch.set(cardDoc, {
            cardNo: card.cartela_no,
            numbers: numbers25,
        });

        processed++;

        // Commit in chunks of 500
        if (processed % 500 === 0) {
            await batch.commit();
            console.log(`[Progress] Seeded ${processed} / ${allCards.length} cards...`);
            batch = db.batch();
            // Brief pause to avoid resource contention
            await new Promise(resolve => setTimeout(resolve, 50));
        }
    }

    // Commit any remaining cards
    if (processed % 500 !== 0) {
        await batch.commit();
    }

    console.log(`\n🎉 SUCCESS: Successfully seeded ${processed} cards into the 'cartelas_pool' Firestore collection!`);
    process.exit(0);
}

seedPool().catch(err => {
    console.error("FATAL ERROR during seeding:", err);
    process.exit(1);
});
