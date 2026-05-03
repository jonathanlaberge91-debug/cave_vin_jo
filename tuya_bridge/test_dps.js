const TuyAPI = require('tuyapi');

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function readAll() {
  const device = new TuyAPI({
    id: 'eb103f9b9dda5093b8k8ae',
    key: 'S&Fg>g;x^6*61&Fu',
    ip: '10.0.0.71',
    version: '3.5',
    issueGetOnConnect: false,
    nullPayloadOnJSONError: true,
  });
  return new Promise((resolve) => {
    const timer = setTimeout(() => { try { device.disconnect(); } catch(_){} resolve(null); }, 10000);
    device.on('data', (data) => { clearTimeout(timer); try { device.disconnect(); } catch(_){} resolve(data.dps); });
    device.on('error', () => { clearTimeout(timer); try { device.disconnect(); } catch(_){} resolve(null); });
    device.find({ timeout: 5 }).then(() => device.connect()).then(() => sleep(1000)).then(() => device.get({ schema: true }))
      .catch(() => { clearTimeout(timer); try { device.disconnect(); } catch(_){} resolve(null); });
  });
}

async function rawSet(dps, value) {
  const device = new TuyAPI({
    id: 'eb103f9b9dda5093b8k8ae',
    key: 'S&Fg>g;x^6*61&Fu',
    ip: '10.0.0.71',
    version: '3.5',
    issueGetOnConnect: false,
    nullPayloadOnJSONError: true,
  });
  await new Promise(async (resolve) => {
    const timer = setTimeout(() => { try { device.disconnect(); } catch(_){} resolve(); }, 12000);
    device.on('error', () => {});
    await device.find({ timeout: 5 });
    await device.connect();
    await sleep(1000);
    const payload = { protocol: 5, t: Math.floor(Date.now() / 1000), data: { dps: { [dps.toString()]: value } } };
    const parser = device.device.parser;
    const seqN = ++device._currentSequenceN;
    const buffer = parser.encode({ data: payload, encrypted: true, commandByte: 13, sequenceN: seqN });
    device._currentSequenceN++;
    await device._send(buffer);
    await sleep(2500);
    clearTimeout(timer);
    try { device.disconnect(); } catch(_){}
    resolve();
  });
}

(async () => {
  console.log('=== Read all DPS ===');
  let dps = await readAll();
  console.log(JSON.stringify(dps, null, 2));
  console.log(`\nDPS 10 = ${dps['10']} (type: ${typeof dps['10']})`);
  console.log(`DPS 107 = ${dps['107']} (type: ${typeof dps['107']})`);

  // Toggle DPS 107 (probably interior light)
  const current107 = dps['107'];
  console.log(`\n=== Toggle DPS 107: ${current107} -> ${!current107} ===`);
  console.log('>> Check if the interior light changes on the cellar!');
  await sleep(1500);
  await rawSet(107, !current107);
  await sleep(2000);
  dps = await readAll();
  console.log(`DPS 107 is now: ${dps['107']}`);

  // Reset it back after 5 seconds
  await sleep(5000);
  console.log(`\n=== Reset DPS 107 back to ${current107} ===`);
  await rawSet(107, current107);
  await sleep(2000);
  dps = await readAll();
  console.log(`DPS 107 is now: ${dps['107']}`);

  // Test DPS 10 values
  console.log(`\n=== Test DPS 10 ===`);
  console.log(`Current: ${dps['10']}`);
  for (const v of [1, 2, true, 'on']) {
    await sleep(1500);
    console.log(`  Setting DPS 10 = ${JSON.stringify(v)}...`);
    await rawSet(10, v);
    await sleep(2000);
    dps = await readAll();
    console.log(`  DPS 10 is now: ${dps['10']}`);
    if (dps['10'] !== 0) break;
  }

  // Reset DPS 10
  if (dps['10'] !== 0) {
    await sleep(1500);
    await rawSet(10, 0);
  }

  process.exit(0);
})();
