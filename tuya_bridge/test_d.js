const TuyAPI = require('tuyapi');

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

const device = new TuyAPI({
  id: 'eb53160c227afdea2evnfe',
  key: 'S&Fg>g;x^6*61&Fu',
  ip: '10.0.0.78',
  version: '3.5',
  issueGetOnConnect: false,
  nullPayloadOnJSONError: true,
});

(async () => {
  console.log('Connecting to Wine CellR D @ 10.0.0.78...');

  device.on('error', (err) => {
    console.log('Error:', err.message);
  });

  device.on('data', (data) => {
    console.log('\nDATA received:');
    console.log(JSON.stringify(data, null, 2));
    device.disconnect();
    process.exit(0);
  });

  try {
    await device.find({ timeout: 5 });
    console.log('Found! Connecting...');
    await device.connect();
    console.log('Connected! Requesting schema...');
    await sleep(1500);
    await device.get({ schema: true });
  } catch (e) {
    console.log('Failed:', e.message);
    process.exit(1);
  }

  setTimeout(() => {
    console.log('Timeout - no data received');
    process.exit(1);
  }, 12000);
})();
