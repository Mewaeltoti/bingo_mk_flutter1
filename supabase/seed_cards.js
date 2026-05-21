// Seeding script for Supabase cards_pool table

const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// Read Supabase environment variables from command args or prompt
const supabaseUrl = process.argv[2];
const supabaseServiceKey = process.argv[3];

if (!supabaseUrl || !supabaseServiceKey) {
  console.error("Usage: node seed_cards.js <SUPABASE_URL> <SUPABASE_SERVICE_ROLE_KEY>");
  console.log("\nNote: Please use the SERVICE_ROLE_KEY so that Row Level Security is bypassed during seeding.");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    persistSession: false
  }
});

async function seed() {
  const dataPath = path.join(__dirname, '..', 'assets', 'data.json');
  if (!fs.existsSync(dataPath)) {
    console.error(`Error: data.json not found at ${dataPath}`);
    process.exit(1);
  }

  console.log("Reading data.json...");
  const rawData = fs.readFileSync(dataPath, 'utf8');
  const allCards = JSON.parse(rawData);
  console.log(`Loaded ${allCards.length} cards from data.json.`);

  const formattedCards = allCards.map(card => {
    const originalNumbers = card.bingo_numbers;
    const numbers25 = [...originalNumbers];
    
    // Standardize 24-number format to 25-number format by putting the free space (0) at index 12
    if (numbers25.length === 24) {
      numbers25.splice(12, 0, 0);
    }
    
    return {
      card_no: card.cartela_no,
      numbers: numbers25
    };
  });

  const batchSize = 500;
  console.log(`Starting bulk insert into cards_pool in batches of ${batchSize}...`);

  for (let i = 0; i < formattedCards.length; i += batchSize) {
    const batch = formattedCards.slice(i, i + batchSize);
    
    const { error } = await supabase
      .from('cards_pool')
      .upsert(batch, { onConflict: 'card_no' });

    if (error) {
      console.error(`Error inserting batch starting at index ${i}:`, error.message);
      process.exit(1);
    } else {
      console.log(`Successfully seeded cards ${i + 1} to ${Math.min(i + batchSize, formattedCards.length)}`);
    }
  }

  console.log("\nDatabase cards_pool seeding completed successfully!");
}

seed().catch(err => {
  console.error("Seeding failed with error:", err);
  process.exit(1);
});
