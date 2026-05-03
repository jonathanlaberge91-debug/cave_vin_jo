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
      res.on('end', () => { try { resolve(JSON.parse(data)); } catch (e) { reject(new Error(data)); } });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

(async () => {
  const tokenRes = await request('GET', '/v1.0/token?grant_type=1');
  const token = tokenRes.result.access_token;

  const deviceId = 'eb103f9b9dda5093b8k8ae';

  // Try sending zone 2 switch via DPS number
  console.log('--- Try zone2 switch via code "5" ---');
  let r = await request('POST', `/v1.0/iot-03/devices/${deviceId}/commands`, token,
    JSON.stringify({ commands: [{ code: '5', value: false }] }));
  console.log(JSON.stringify(r));

  // Try raw DP instruction
  console.log('\n--- Try raw DP instruction format ---');
  r = await request('POST', `/v1.0/devices/${deviceId}/commands`, token,
    JSON.stringify({ commands: [{ code: 'switch', value: true }, { code: 'temp_set', value: 12 }] }));
  console.log(JSON.stringify(r));

  // Get full device specification to see all DP codes
  console.log('\n--- Device specification ---');
  r = await request('GET', `/v1.0/devices/${deviceId}/specifications`, token);
  console.log(JSON.stringify(r, null, 2));

  // Try standard instruction set
  console.log('\n--- Standard instruction set ---');
  r = await request('GET', `/v1.0/iot-03/devices/${deviceId}/specification`, token);
  console.log(JSON.stringify(r, null, 2));

  // Check both devices for their full DPS mapping
  console.log('\n--- Device D functions ---');
  r = await request('GET', `/v1.0/devices/eb53160c227afdea2evnfe/functions`, token);
  console.log(JSON.stringify(r, null, 2));

  process.exit(0);
})();
