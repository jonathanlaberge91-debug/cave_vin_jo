const TuyAPI = require('tuyapi');

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// Cloud says Wine CellR G has key H`R3p5<_Oa4CzEpE
// But we know .71 works with S&Fg>g;x^6*61&Fu
// So try the backtick key on .78
const combos = [
  { label: 'backtick key + evnfe v3.5', id: 'eb53160c227afdea2evnfe', key: 'H`R3p5<_Oa4CzEpE', ver: '3.5' },
  { label: 'backtick key + evnfe v3.3', id: 'eb53160c227afdea2evnfe', key: 'H`R3p5<_Oa4CzEpE', ver: '3.3' },
  { label: 'backtick key + 8k8ae v3.5', id: 'eb103f9b9dda5093b8k8ae', key: 'H`R3p5<_Oa4CzEpE', ver: '3.5' },
  { label: 'backtick key + 8k8ae v3.3', id: 'eb103f9b9dda5093b8k8ae', key: 'H`R3p5<_Oa4CzEpE', ver: '3.3' },
];

const ip = '10.0.0.78';

async function tryCombo(c) {
  const device = new TuyAPI({
    id: c.id, key: c.key, ip, version: c.ver,
    issueGetOnConnect: false,
    nullPayloadOnJSONError: true,
  });

  return new Promise((resolve) => {
    let settled = false;
    const done = (r) => { if (!settled) { settled = true; resolve(r); } };
    const timeout = setTimeout(() => { try { device.disconnect(); } catch(_){} done(null); }, 10000);

    device.on('error', () => { clearTimeout(timeout); try { device.disconnect(); } catch(_){} done(null); });
    device.on('data', (data) => {
      console.log(`\n>>> SUCCESS: ${c.label}`);
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
  console.log('Testing 10.0.0.78 with backtick key: H`R3p5<_Oa4CzEpE\n');
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
