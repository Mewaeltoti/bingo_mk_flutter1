const admin = require("firebase-admin");
const fs = require("fs");

admin.initializeApp({
  projectId: "my-bingo-mk"
});

const db = admin.firestore();
const dataPath = "./data.json";
const rawData = fs.readFileSync(dataPath, "utf8");
const allCards = JSON.parse(rawData);

async function seed() {
    console.log("Starting seed of " + allCards.length + " cards");
    const poolRef = db.collection("cartelas_pool");
    let batch = db.batch();
    let processed = 0;

    for (const card of allCards) {
        const originalNumbers = card.bingo_numbers;
        const numbers25 = [...originalNumbers];

        if (numbers25.length === 24) {
            numbers25.splice(12, 0, 0);
        }

        const cardDoc = poolRef.doc(card.cartela_no.toString());
        batch.set(cardDoc, {
            cardNo: card.cartela_no,
            numbers: numbers25,
        });

        processed++;
        if (processed % 400 === 0) {
            await batch.commit();
            console.log("Committed " + processed);
            batch = db.batch();
        }
    }

    if (processed % 400 !== 0) {
        await batch.commit();
    }
    console.log("Done seeding " + processed + " cards!");
}

seed().catch(console.error);
