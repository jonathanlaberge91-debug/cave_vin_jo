const TuyAPI = require('tuyapi');

// Focus on 10.0.0.78 which didn't respond - try many variations of key1
const ip = '10.0.0.78';
const ids = ['eb103f9b9dda5093b8k8ae', 'eb53160c227afdea2evnfe'];

// All possible interpretations of H\R3p5<_Oa4CzEpE`
const keys = [
  { label: 'original with backslash', val: 'H\\R3p5<_Oa4CzEpE' },
  { label: 'with backtick at end', val: 'HR3p5<_Oa4CzEpE`' },
  { label: 'full with both', val: 'H\\R3p5<_Oa4CzEpE`' },  // 17 chars but try
  { label: 'no special, backtick', val: 'HR3p5<_Oa4CzEpE`' },
  { label: 'backslash R as just R', val: 'HR3p5<_Oa4CzEpE' },  // 15 chars
  // Maybe < was actually ( or { or [
  { label: '< as (', val: 'H\\R3p5(_Oa4CzEpE' },
  { label: '< as {', val: 'H\\R3p5{_Oa4CzEpE' },
  // Maybe backtick was actually ' (single quote)
  { label: "with single quote", val: "HR3p5<_Oa4CzEpE'" },
  // Maybe same key as other device
  { label: 'same key as cellier 1', val: 'S&Fg>g;x^6*61&Fu' },
  // Maybe the _ was actually a space
  { label: '_ as space', val: 'H\\R3p5< Oa4CzEpE' },
  // Maybe E` was actually E1 or Eq
  { label: 'backtick as 1', val: 'H\\R3p5<_Oa4CzEp1' },
  { label: 'no backslash no backtick padded', val: 'HR3p5<_Oa4CzEpEE' },
];

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function tryCombo(id, key, ver) {
  if (key.val.length !== 16) return null;

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
      console.log(`\n>>> SUCCESS [${key.label}] v${ver} id:${id.slice(-6)}`);
      console.log(JSON.stringify(data, null, 2));
      clearTimeout(timeout);
      try { device.disconnect(); } catch (_) {}
      done({ id, key: key.val, keyLabel: key.label, ver, data });
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
  console.log(`Brute-forcing 10.0.0.78 with key variations...\n`);
  const validKeys = keys.filter(k => k.val.length === 16);
  console.log(`${validKeys.length} valid 16-char keys to try x ${ids.length} IDs x 2 versions = ${validKeys.length * ids.length * 2} combos\n`);

  const successes = [];
  let n = 0;

  for (const id of ids) {
    for (const key of validKeys) {
      for (const ver of ['3.5', '3.3']) {
        n++;
        process.stdout.write(`\r${n} - ${key.label} | v${ver} | ${id.slice(-6)}      `);
        const result = await tryCombo(id, key, ver);
        if (result) successes.push(result);
        await sleep(500);
      }
    }
  }

  console.log(`\n\nDone. ${successes.length} working combo(s).`);
  for (const s of successes) {
    console.log(`  Key: ${s.keyLabel} = [${s.key}]`);
    console.log(`  Version: ${s.ver}, Device: ${s.id}`);
  }
  process.exit(0);
})();
