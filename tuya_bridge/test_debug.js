process.env.DEBUG = 'TuyAPI';
const TuyAPI = require('tuyapi');

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

const device = new TuyAPI({
  id: 'eb103f9b9dda5093b8k8ae',
  key: 'S&Fg>g;x^6*61&Fu',
  ip: '10.0.0.71',
  version: '3.5',
  issueGetOnConnect: false,
  nullPayloadOnJSONError: true,
});

(async () => {
  device.on('error', (e) => console.log('ERROR:', e));
  device.on('data', (d) => console.log('DATA:', JSON.stringify(d)));

  await device.find({ timeout: 5 });
  console.log('Found');
  await device.connect();
  console.log('Connected');
  await sleep(1500);

  // First do a successful GET
  console.log('\n=== GET ===');
  try {
    const data = await device.get({ schema: true });
    console.log('GET result:', JSON.stringify(data));
  } catch (e) {
    console.log('GET error:', e.message);
  }

  await sleep(1000);

  // Now try SET
  console.log('\n=== SET dps=2 value=11 ===');
  try {
    const result = await device.set({ dps: 2, set: 11, shouldWaitForResponse: false });
    console.log('SET result:', result);
  } catch (e) {
    console.log('SET error:', e.message);
  }

  await sleep(3000);
  device.disconnect();
  process.exit(0);
})();
