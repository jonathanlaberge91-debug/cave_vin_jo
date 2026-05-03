const TuyAPI = require('tuyapi');

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

const cellar = {
  id: 'eb103f9b9dda5093b8k8ae',
  key: 'S&Fg>g;x^6*61&Fu',
  ip: '10.0.0.71',
  version: '3.5',
};

async function testSet(label, setArgs) {
  const device = new TuyAPI({
    id: cellar.id,
    key: cellar.key,
    ip: cellar.ip,
    version: cellar.version,
    issueGetOnConnect: false,
    nullPayloadOnJSONError: true,
  });

  console.log(`\n--- ${label} ---`);

  return new Promise(async (resolve) => {
    const timer = setTimeout(() => {
      console.log('  TIMEOUT');
      try { device.disconnect(); } catch (_) {}
      resolve(false);
    }, 15000);

    device.on('error', (err) => {
      console.log(`  ERROR: ${err}`);
    });

    device.on('data', (data) => {
      console.log(`  DATA:`, JSON.stringify(data));
      clearTimeout(timer);
      try { device.disconnect(); } catch (_) {}
      resolve(true);
    });

    try {
      await device.find({ timeout: 5 });
      console.log('  Found, connecting...');
      await device.connect();
      console.log('  Connected, waiting...');
      await sleep(1500);

      console.log(`  Sending set:`, JSON.stringify(setArgs));
      await device.set(setArgs);
      console.log('  set() returned OK');

      // Wait for data event
      await sleep(5000);
      clearTimeout(timer);
      try { device.disconnect(); } catch (_) {}
      resolve(false);
    } catch (e) {
      console.log(`  CATCH: ${e.message}`);
      clearTimeout(timer);
      try { device.disconnect(); } catch (_) {}
      resolve(false);
    }
  });
}

(async () => {
  // Test 1: set temperature as number dps
  await testSet('dps as number: set temp to 13', { dps: 2, set: 13 });
  await sleep(2000);

  // Test 2: set temperature as string dps
  await testSet('dps as string: set temp to 12', { dps: '2', set: 12 });
  await sleep(2000);

  // Test 3: multiple mode
  await testSet('multiple mode: LED green', { multiple: true, data: { '102': 'green' } });
  await sleep(2000);

  // Test 4: single LED set
  await testSet('single LED: dps 102 green', { dps: 102, set: 'green' });
  await sleep(2000);

  // Test 5: power toggle
  await testSet('power on: dps 1 true', { dps: 1, set: true });

  console.log('\nDone');
  process.exit(0);
})();
