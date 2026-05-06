const admin = require('../functions/node_modules/firebase-admin');

admin.initializeApp({ projectId: 'cave-vin-jo' });
const db = admin.firestore();

// Same data as tuya_bridge/server.js
const CELLARS = [
  { name: 'Wine CellR D', id: 'eb103f9b9dda5093b8k8ae', key: 'S&Fg>g;x^6*61&Fu', ip: '10.0.0.71', version: '3.5' },
  { name: 'Wine CellR G', id: 'eb53160c227afdea2evnfe', key: 'H`R3p5<_Oa4CzEpE', ip: '10.0.0.78', version: '3.5' },
];

async function run() {
  const snap = await db.collection('cellars').orderBy('number').get();
  const docs = snap.docs;

  console.log(`${docs.length} cellier(s) trouvé(s) dans Firestore :`);
  for (const d of docs) {
    const data = d.data();
    console.log(`  #${data.number} "${data.name || ''}" — id: ${d.id} — tuyaDeviceId: ${data.tuyaDeviceId || '(none)'}`);
  }

  // Match by name
  for (const doc of docs) {
    const cellarName = doc.data().name || '';
    const tuya = CELLARS.find(c => c.name === cellarName);
    if (!tuya) {
      console.log(`⚠ Aucun match Tuya pour "${cellarName}" — ignoré`);
      continue;
    }
    await db.collection('cellars').doc(doc.id).update({
      tuyaDeviceId: tuya.id,
      tuyaLocalKey: tuya.key,
      tuyaIp: tuya.ip,
      tuyaVersion: tuya.version,
    });
    console.log(`✓ "${cellarName}" → id=${tuya.id} key=${tuya.key} ip=${tuya.ip} v${tuya.version}`);
  }

  console.log('Done.');
  process.exit(0);
}

run().catch(e => { console.error(e.message); process.exit(1); });
