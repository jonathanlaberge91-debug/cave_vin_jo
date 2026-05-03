const TuyAPI = require('tuyapi');

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

const cellar = {
  id: 'eb103f9b9dda5093b8k8ae',
  key: 'S&Fg>g;x^6*61&Fu',
  ip: '10.0.0.71',
  version: '3.5',
};

async function readStatus() {
  const device = new TuyAPI({ ...cellar, issueGetOnConnect: false, nullPayloadOnJSONError: true });
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { try { device.disconnect(); } catch(_){} reject(new Error('timeout')); }, 10000);
    device.on('data', (data) => { clearTimeout(timer); try { device.disconnect(); } catch(_){} resolve(data); });
    device.on('error', (e) => { clearTimeout(timer); try { device.disconnect(); } catch(_){} reject(e); });
    device.find({ timeout: 5 }).then(() => device.connect()).then(() => sleep(1000)).then(() => device.get({ schema: true }))
      .catch(e => { clearTimeout(timer); try { device.disconnect(); } catch(_){} reject(e); });
  });
}

async function setNoWait(dps, value) {
  const device = new TuyAPI({ ...cellar, issueGetOnConnect: false, nullPayloadOnJSONError: true });

  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { try { device.disconnect(); } catch(_){} resolve('timeout-ok'); }, 8000);

    device.on('error', (e) => {
      console.log(`  error event: ${e}`);
    });

    device.on('data', (data) => {
      console.log(`  data event:`, JSON.stringify(data));
      clearTimeout(timer);
      try { device.disconnect(); } catch(_){}
      resolve('data');
    });

    device.find({ timeout: 5 })
      .then(() => device.connect())
      .then(() => sleep(1000))
      .then(async () => {
        console.log(`  Sending SET (shouldWaitForResponse=false) dps=${dps} value=${JSON.stringify(value)}`);
        await device.set({ dps, set: value, shouldWaitForResponse: false });
        console.log('  set() returned immediately');
        await sleep(3000);
        clearTimeout(timer);
        try { device.disconnect(); } catch(_){}
        resolve('sent');
      })
      .catch(e => {
        clearTimeout(timer);
        try { device.disconnect(); } catch(_){}
        reject(e);
      });
  });
}

(async () => {
  // Read initial status
  console.log('=== Initial status ===');
  let status = await readStatus();
  console.log(`  temp: ${status.dps['2']}, LED: ${status.dps['102']}`);
  await sleep(1000);

  // Test 1: Set temperature to 11 (shouldWaitForResponse=false)
  console.log('\n=== Set temp to 11 (no-wait) ===');
  const r1 = await setNoWait(2, 11);
  console.log(`  result: ${r1}`);
  await sleep(2000);

  // Read status after
  console.log('\n=== Status after temp set ===');
  status = await readStatus();
  console.log(`  temp: ${status.dps['2']}, LED: ${status.dps['102']}`);
  await sleep(1000);

  // Test 2: Set LED to green (no-wait)
  console.log('\n=== Set LED to green (no-wait) ===');
  const r2 = await setNoWait(102, 'green');
  console.log(`  result: ${r2}`);
  await sleep(2000);

  // Read final status
  console.log('\n=== Final status ===');
  status = await readStatus();
  console.log(`  temp: ${status.dps['2']}, LED: ${status.dps['102']}`);

  // Reset temp back to 12
  console.log('\n=== Reset temp to 12 ===');
  await setNoWait(2, 12);
  await sleep(2000);
  status = await readStatus();
  console.log(`  temp: ${status.dps['2']}`);

  process.exit(0);
})();
