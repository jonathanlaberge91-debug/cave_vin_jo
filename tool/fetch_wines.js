const admin = require('../functions/node_modules/firebase-admin');
const fs = require('fs');

admin.initializeApp({ projectId: 'cave-vin-jo' });
const db = admin.firestore();

async function run() {
  const [winesSnap, bottlesSnap] = await Promise.all([
    db.collection('wines').limit(100).get(),
    db.collection('bottles').where('status', '==', 'inCave').limit(500).get(),
  ]);
  const wines = winesSnap.docs.map(d => ({ id: d.id, ...d.data() }));
  const bottles = bottlesSnap.docs.map(d => ({ id: d.id, ...d.data() }));
  fs.writeFileSync('tool/wines_data.json', JSON.stringify({ wines, bottles }, null, 2));
  console.log(`Fetched ${wines.length} wines, ${bottles.length} bottles`);
}
run().catch(e => { console.error(e.message); process.exit(1); });
