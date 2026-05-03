const TuyAPI = require('tuyapi');

const ip = '10.0.0.78';
const key = 'H\\R3p5<_Oa4CzEpE';
const ids = ['eb103f9b9dda5093b8k8ae', 'eb53160c227afdea2evnfe'];
const versions = ['3.5', '3.3', '3.4', '3.1'];

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function tryCombo(id, ver) {
  const device = new TuyAPI({
    id, key, ip, version: ver,
    issueGetOnConnect: false,
    nullPayloadOnJSONError: true,
  });

  return new Promise((resolve) => {
    let settled = false;
    const done = (r) => { if (!settled) { settled = true; resolve(r); } };
    const timeout = setTimeout(() => { try { device.disconnect(); } catch(_){} done(null); }, 10000);

    device.on('error', () => { clearTimeout(timeout); try { device.disconnect(); } catch(_){} done(null); });
    device.on('data', (data) => {
      console.log(`\n>>> SUCCESS v${ver} id:${id.slice(-6)}`);
      console.log(JSON.stringify(data, null, 2));
      clearTimeout(timeout);
      try { device.disconnect(); } catch(_){}
      done(data);
    });

    device.find({ timeout: 5 }).then(() => device.connect())
      .then(() => sleep(2000))
      .then(() => device.get({ schema: true }))
      .catch(() => { clearTimeout(timeout); try { device.disconnect(); } catch(_){} done(null); });
  });
}

(async () => {
  console.log(`Testing 10.0.0.78 with key [${key}] (${key.length} chars)\n`);
  for (const id of ids) {
    for (const ver of versions) {
      process.stdout.write(`${id.slice(-6)} v${ver}... `);
      const r = await tryCombo(id, ver);
      if (r) { console.log('FOUND!'); process.exit(0); }
      else console.log('fail');
      await sleep(500);
    }
  }
  console.log('\nNothing worked.');
  process.exit(0);
})();
