const crypto = require('crypto');
const https = require('https');

const ACCESS_ID = 'fj3v7v73dvschschp949';
const ACCESS_SECRET = 'e0bf1dccdb0641e3b4beef3f046d8715';
const HOST = 'openapi.tuyaus.com';

function sign(method, path, headers, body) {
  const t = headers['t'];
  const contentHash = crypto.createHash('sha256').update(body || '').digest('hex');
  const stringToSign = [method, contentHash, '', path].join('\n');
  const str = ACCESS_ID + (headers['access_token'] || '') + t + stringToSign;
  return crypto.createHmac('sha256', ACCESS_SECRET).update(str).digest('hex').toUpperCase();
}

function request(method, path, token, body) {
  return new Promise((resolve, reject) => {
    const t = Date.now().toString();
    const headers = {
      'client_id': ACCESS_ID,
      't': t,
      'sign_method': 'HMAC-SHA256',
      'Content-Type': 'application/json',
    };
    if (token) headers['access_token'] = token;
    headers['sign'] = sign(method, path, headers, body);

    const opts = { hostname: HOST, port: 443, path, method, headers };
    const req = https.request(opts, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); } catch (e) { reject(new Error(data)); }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

// DPS to Tuya standard code mapping
const DPS_MAP = {
  '1': { code: 'switch', type: 'bool' },
  '2': { code: 'temp_set', type: 'int' },
  '4': { code: 'temp_unit_convert', type: 'string' },
  '5': { code: 'switch', type: 'bool' },  // zone low uses same code?
  '6': { code: 'temp_set', type: 'int' },
  '101': { code: 'child_lock', type: 'bool' },
  '102': { code: 'colour_data', type: 'string' },
  '106': { code: 'fault', type: 'string' },
};

(async () => {
  // Get token
  const tokenRes = await request('GET', '/v1.0/token?grant_type=1');
  if (!tokenRes.success) { console.log('Token failed:', tokenRes.msg); process.exit(1); }
  const token = tokenRes.result.access_token;
  console.log('Token OK');

  const deviceId = 'eb103f9b9dda5093b8k8ae';

  // First, get the device's function specs
  console.log('\n--- Device functions ---');
  const funcsRes = await request('GET', `/v1.0/devices/${deviceId}/functions`, token);
  console.log(JSON.stringify(funcsRes, null, 2));

  // Get current status
  console.log('\n--- Current status ---');
  const statusRes = await request('GET', `/v1.0/devices/${deviceId}/status`, token);
  console.log(JSON.stringify(statusRes, null, 2));

  // Try to send a command: set temperature to 13
  console.log('\n--- Set temp to 13 ---');
  const cmdBody = JSON.stringify({
    commands: [{ code: 'temp_set', value: 13 }]
  });
  const cmdRes = await request('POST', `/v1.0/iot-03/devices/${deviceId}/commands`, token, cmdBody);
  console.log(JSON.stringify(cmdRes, null, 2));

  // Try LED color
  console.log('\n--- Set LED to green ---');
  const ledBody = JSON.stringify({
    commands: [{ code: 'colour_data', value: 'green' }]
  });
  const ledRes = await request('POST', `/v1.0/iot-03/devices/${deviceId}/commands`, token, ledBody);
  console.log(JSON.stringify(ledRes, null, 2));

  // Wait and check status
  await new Promise(r => setTimeout(r, 3000));
  console.log('\n--- Status after commands ---');
  const statusRes2 = await request('GET', `/v1.0/devices/${deviceId}/status`, token);
  console.log(JSON.stringify(statusRes2, null, 2));

  process.exit(0);
})();
