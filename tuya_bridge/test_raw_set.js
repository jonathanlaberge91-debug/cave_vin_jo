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

  return new Promise(async (resolve) => {
    const timer = setTimeout(() => { try { device.disconnect(); } catch(_){} resolve('timeout'); }, 15000);

    device.on('error', e => console.log('  error:', e));
    device.on('data', d => {
      console.log('  data:', JSON.stringify(d));
    });

    await device.find({ timeout: 5 });
    await device.connect();
    await sleep(1500);

    // Build minimal payload like tinytuya
    const payload = {
      protocol: 5,
      t: Math.floor(Date.now() / 1000),
      data: {
        dps: { [dps.toString()]: value }
      }
    };

    console.log('  Sending raw payload:', JSON.stringify(payload));

    // Access internal parser and sequence
    const parser = device.device.parser;
    const seqN = ++device._currentSequenceN;

    const buffer = parser.encode({
      data: payload,
      encrypted: true,
      commandByte: 13, // CONTROL_NEW
      sequenceN: seqN,
    });

    device._currentSequenceN++; // Extra increment for 3.5

    // Send raw buffer
    await device._send(buffer);
    console.log('  Sent! Waiting for response...');

    await sleep(4000);
    clearTimeout(timer);
    try { device.disconnect(); } catch(_){}
    resolve('sent');
  });
}

async function readStatus() {
  const device = new TuyAPI({
    id: 'eb103f9b9dda5093b8k8ae',
    key: 'S&Fg>g;x^6*61&Fu',
    ip: '10.0.0.71',
    version: '3.5',
    issueGetOnConnect: false,
    nullPayloadOnJSONError: true,
  });
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { try { device.disconnect(); } catch(_){} reject(new Error('timeout')); }, 10000);
    device.on('data', (data) => { clearTimeout(timer); try { device.disconnect(); } catch(_){} resolve(data); });
    device.on('error', (e) => { clearTimeout(timer); try { device.disconnect(); } catch(_){} reject(e); });
    device.find({ timeout: 5 }).then(() => device.connect()).then(() => sleep(1000)).then(() => device.get({ schema: true }))
      .catch(e => { clearTimeout(timer); try { device.disconnect(); } catch(_){} reject(e); });
  });
}

(async () => {
  // Read initial
  console.log('=== Initial ===');
  let s = await readStatus();
  console.log(`  temp=${s.dps['2']} LED=${s.dps['102']}`);
  await sleep(1500);

  // Test 1: set temp to 11 with minimal payload
  console.log('\n=== Raw SET temp=11 ===');
  await rawSet(2, 11);
  await sleep(2000);

  // Read after
  console.log('\n=== After SET ===');
  s = await readStatus();
  console.log(`  temp=${s.dps['2']} LED=${s.dps['102']}`);

  if (s.dps['2'] === 11) {
    console.log('\n>>> TEMP CHANGED! Trying LED...');
    await sleep(1500);
    console.log('\n=== Raw SET LED=green ===');
    await rawSet(102, 'green');
    await sleep(2000);
    s = await readStatus();
    console.log(`  LED=${s.dps['102']}`);

    // Reset temp
    await sleep(1500);
    await rawSet(2, 12);
  } else {
    console.log('\n>>> Temp did NOT change');
  }

  process.exit(0);
})();
