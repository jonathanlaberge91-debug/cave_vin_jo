const TuyAPI = require('tuyapi');

const ips = ['10.0.0.71', '10.0.0.78'];
const ids = ['eb103f9b9dda5093b8k8ae', 'eb53160c227afdea2evnfe'];
const keys = [
  { label: 'key1 (backslash, no backtick)', val: 'H\\R3p5<_Oa4CzEpE' },
  { label: 'key1 (no backslash, with backtick)', val: 'HR3p5<_Oa4CzEpE`' },
  { label: 'key2', val: 'S&Fg>g;x^6*61&Fu' },
];
const versions = ['3.3', '3.4', '3.5', '3.1'];

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function tryCombo(ip, id, key, ver) {
  const tag = `[${ip} | ${id.slice(-6)} | ${key.label} | v${ver}]`;

  const device = new TuyAPI({
    id, key: key.val, ip, version: ver,
    issueGetOnConnect: false,
    nullPayloadOnJSONError: true,
  });

  return new Promise((resolve) => {
    let settled = false;
    const done = (result) => { if (!settled) { settled = true; resolve(result); } };

    const timeout = setTimeout(() => {
      try { device.disconnect(); } catch (_) {}
      done(null);
    }, 8000);

    device.on('error', () => {
      clearTimeout(timeout);
      try { device.disconnect(); } catch (_) {}
      done(null);
    });

    device.on('data', (data) => {
      console.log(`\n>>> SUCCESS ${tag}`);
      console.log(JSON.stringify(data, null, 2));
      clearTimeout(timeout);
      try { device.disconnect(); } catch (_) {}
      done({ ip, id, key: key.val, keyLabel: key.label, ver, data });
    });

    device.find({ timeout: 4 }).then(() => {
      return device.connect();
    }).then(() => {
      return sleep(1500);
    }).then(() => {
      return device.get({ schema: true });
    }).catch(() => {
      clearTimeout(timeout);
      try { device.disconnect(); } catch (_) {}
      done(null);
    });
  });
}

(async () => {
  console.log('Testing all combinations...\n');
  const successes = [];
  let total = ips.length * ids.length * keys.length * versions.length;
  let n = 0;

  for (const ip of ips) {
    for (const id of ids) {
      for (const key of keys) {
        for (const ver of versions) {
          n++;
          process.stdout.write(`\r${n}/${total} - ${ip} | ${id.slice(-6)} | ${key.label} | v${ver}    `);
          const result = await tryCombo(ip, id, key, ver);
          if (result) {
            successes.push(result);
            console.log(`\n*** FOUND WORKING COMBO ***`);
          }
          await sleep(500);
        }
      }
    }
  }

  console.log(`\n\n${'='.repeat(50)}`);
  console.log(`Scan complete. ${successes.length} working combo(s) found.`);
  for (const s of successes) {
    console.log(`\n  IP: ${s.ip}`);
    console.log(`  Device ID: ${s.id}`);
    console.log(`  Key: ${s.keyLabel} = [${s.key}]`);
    console.log(`  Version: ${s.ver}`);
    console.log(`  Data: ${JSON.stringify(s.data)}`);
  }

  process.exit(0);
})();
