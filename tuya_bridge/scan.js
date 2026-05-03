const TuyAPI = require('tuyapi');

// Try both key interpretations for Cellier D
const devices = [
  {
    name: 'Cellier D (Droite) - key with backslash',
    id: 'eb103f9b9dda5093b8k8ae',
    key: 'H\\R3p5<_Oa4CzEpE',
    ip: '10.0.0.71',
  },
  {
    name: 'Cellier D (Droite) - key with backtick',
    id: 'eb103f9b9dda5093b8k8ae',
    key: 'HR3p5<_Oa4CzEpE`',
    ip: '10.0.0.71',
  },
  {
    name: 'Cellier G (Gauche)',
    id: 'eb53160c227afdea2evnfe',
    key: 'S&Fg>g;x^6*61&Fu',
    ip: '10.0.0.78',
  },
];

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function scanDevice(cfg) {
  console.log(`\n${'='.repeat(50)}`);
  console.log(`Scanning: ${cfg.name}`);
  console.log(`IP: ${cfg.ip} | ID: ${cfg.id}`);
  console.log(`Key: [${cfg.key}] (length: ${cfg.key.length})`);
  console.log('='.repeat(50));

  for (const ver of ['3.3', '3.1', '3.4']) {
    console.log(`\n--- Version ${ver} ---`);

    const device = new TuyAPI({
      id: cfg.id,
      key: cfg.key,
      ip: cfg.ip,
      version: ver,
      issueGetOnConnect: false,
      nullPayloadOnJSONError: true,
    });

    let gotData = false;

    device.on('error', (err) => {
      console.log(`  error: ${err.message}`);
    });

    device.on('data', (data) => {
      gotData = true;
      console.log(`\n  >>> DATA RECEIVED (v${ver}):`);
      console.log(JSON.stringify(data, null, 2));
    });

    device.on('connected', () => {
      console.log(`  connected!`);
    });

    device.on('disconnected', () => {
      console.log(`  disconnected`);
    });

    try {
      await device.find({ timeout: 5 });
      await device.connect();

      // Wait a bit before sending commands
      await sleep(2000);

      if (!gotData) {
        try {
          console.log('  Sending get({schema: true})...');
          const schema = await device.get({ schema: true });
          console.log('  Schema:', JSON.stringify(schema, null, 2));
          gotData = true;
        } catch (e) {
          console.log(`  schema get failed: ${e.message}`);
        }
      }

      await sleep(1000);

      if (!gotData) {
        try {
          console.log('  Sending basic get()...');
          const basic = await device.get();
          console.log('  Basic:', JSON.stringify(basic, null, 2));
          gotData = true;
        } catch (e) {
          console.log(`  basic get failed: ${e.message}`);
        }
      }

      // Wait for passive data
      if (!gotData) {
        console.log('  Waiting 10s for passive data...');
        await sleep(10000);
      }

      try { await device.disconnect(); } catch (_) {}

      if (gotData) {
        console.log(`\n  SUCCESS with version ${ver}`);
        return;
      }
    } catch (err) {
      console.log(`  find/connect failed: ${err.message}`);
      try { device.disconnect(); } catch (_) {}
    }

    await sleep(2000);
  }

  console.log('\n  All versions failed for this device.');
}

(async () => {
  for (const d of devices) {
    await scanDevice(d);
  }
  console.log('\n\nAll scans complete.');
  process.exit(0);
})();
