const TuyAPI = require('tuyapi');

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

const combos = [
  { label: 'ID:evnfe v3.5', id: 'eb53160c227afdea2evnfe', ver: '3.5' },
  { label: 'ID:evnfe v3.3', id: 'eb53160c227afdea2evnfe', ver: '3.3' },
  { label: 'ID:evnfe v3.4', id: 'eb53160c227afdea2evnfe', ver: '3.4' },
  { label: 'ID:8k8ae v3.5', id: 'eb103f9b9dda5093b8k8ae', ver: '3.5' },
  { label: 'ID:8k8ae v3.3', id: 'eb103f9b9dda5093b8k8ae', ver: '3.3' },
  { label: 'ID:8k8ae v3.4', id: 'eb103f9b9dda5093b8k8ae', ver: '3.4' },
];

const key = 'S&Fg>g;x^6*61&Fu';
const ip = '10.0.0.78';

async function tryCombo(combo) {
  const device = new TuyAPI({
    id: combo.id,
    key,
    ip,
    version: combo.ver,
    issueGetOnConnect: false,
    nullPayloadOnJSONError: true,
  });

  return new Promise((resolve) => {
    let settled = false;
    const done = (r) => { if (!settled) { settled = true; resolve(r); } };
    const timeout = setTimeout(() => { try { device.disconnect(); } catch(_){} done(null); }, 10000);

    device.on('error', () => { clearTimeout(timeout); try { device.disconnect(); } catch(_){} done(null); });
    device.on('data', (data) => {
      console.log(`\n>>> SUCCESS ${combo.label}`);
      console.log(JSON.stringify(data, null, 2));
      clearTimeout(timeout);
      try { device.disconnect(); } catch(_){}
      done(data);
    });

    device.find({ timeout: 5 }).then(() => device.connect())
      .then(() => sleep(1500))
      .then(() => device.get({ schema: true }))
      .catch(() => { clearTimeout(timeout); try { device.disconnect(); } catch(_){} done(null); });
  });
}

(async () => {
  console.log(`Testing 10.0.0.78 with key [${key}]\n`);
  for (const c of combos) {
    process.stdout.write(`${c.label}... `);
    const r = await tryCombo(c);
    if (r) { console.log('FOUND!'); process.exit(0); }
    else console.log('fail');
    await sleep(500);
  }
  console.log('\nNone worked.');
  process.exit(0);
})();
