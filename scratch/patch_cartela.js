const fs = require('fs');
let content = fs.readFileSync('./functions/cartelaService.js', 'utf8');

// 1. Remove numbers from request destructuring
content = content.replace(
    /const \{ cardId, numbers \} = request\.data \|\| \{\};/g,
    `const { cardId } = request.data || {};`
);

content = content.replace(
    /if \(\!numbers \|\| \!Array\.isArray\(numbers\)\) \{\s*throw new HttpsError\('invalid-argument', 'numbers array is required\.'\);\s*\}/g,
    ""
);

// 2. Fetch numbers from cartelas_pool
content = content.replace(
    /const userDoc = await transaction\.get\(userRef\);\s*const gameDoc = await transaction\.get\(gameRef\);/g,
    `const userDoc = await transaction.get(userRef);
            const gameDoc = await transaction.get(gameRef);

            const poolDoc = await transaction.get(db.collection('cartelas_pool').doc(cardId.toString()));
            if (!poolDoc.exists) throw new Error("Invalid card number. Not found in pool.");
            const numbers = poolDoc.data().numbers;`
);

// 3. Balance deduction using increment
content = content.replace(
    /transaction\.update\(userRef, \{ balance: balance - price \}\);/g,
    `transaction.update(userRef, { balance: admin.firestore.FieldValue.increment(-price) });`
);

fs.writeFileSync('./functions/cartelaService.js', content);
console.log('cartelaService.js patched!');
