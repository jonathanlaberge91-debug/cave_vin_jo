const TuyAPI = require('tuyapi');

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

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
    await sleep(3000);
    clearTimeout(timer);
    try { device.disconnect(); } catch(_){}
    resolve();
  });
}

async function readDps102() {
  const device = new TuyAPI({
    id: 'eb103f9b9dda5093b8k8ae',
    key: 'S&Fg>g;x^6*61&Fu',
    ip: '10.0.0.71',
    version: '3.5',
    issueGetOnConnect: false,
    nullPayloadOnJSONError: true,
  });
  return new Promise((resolve) => {
    const timer = setTimeout(() => { try { device.disconnect(); } catch(_){} resolve('timeout'); }, 10000);
    device.on('data', (data) => { clearTimeout(timer); try { device.disconnect(); } catch(_){} resolve(data.dps['102']); });
    device.on('error', () => { clearTimeout(timer); try { device.disconnect(); } catch(_){} resolve('error'); });
    device.find({ timeout: 5 }).then(() => device.connect()).then(() => sleep(1000)).then(() => device.get({ schema: true }))
      .catch(() => { clearTimeout(timer); try { device.disconnect(); } catch(_){} resolve('error'); });
  });
}

(async () => {
  const values = ['red', 'green', 'blue', 'white', 'colour', 'scene', 'off', 'on', 'warm', 'cold', 1, 2, 3, 4];

  for (const v of values) {
    await rawSet(102, v);
    await sleep(1500);
    const result = await readDps102();
    console.log(`  102=${JSON.stringify(v)} → ${result}`);
    await sleep(1000);
  }

  // Reset to red
  await rawSet(102, 'red');

  process.exit(0);
})();
