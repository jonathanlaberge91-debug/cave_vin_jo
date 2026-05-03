const crypto = require('crypto');
const https = require('https');

const ACCESS_ID = 'fj3v7v73dvschschp949';
const ACCESS_SECRET = 'e0bf1dccdb0641e3b4beef3f046d8715';
const HOST = 'openapi.tuyaus.com'; // Western America

function sign(method, path, headers, body) {
  const t = headers['t'];
  const nonce = '';
  const stringToSign = [method, crypto.createHash('sha256').update(body || '').digest('hex'), '', path].join('\n');
  const str = ACCESS_ID + (headers['access_token'] || '') + t + nonce + stringToSign;
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
        try { resolve(JSON.parse(data)); }
        catch (e) { reject(new Error(data)); }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

(async () => {
  try {
    // Get access token
    console.log('Getting access token...');
    const tokenRes = await request('GET', '/v1.0/token?grant_type=1');
    console.log('Token response:', JSON.stringify(tokenRes, null, 2));

    if (!tokenRes.success) {
      console.log('Failed to get token. Trial may be expired.');
      process.exit(1);
    }

    const token = tokenRes.result.access_token;

    // Get all devices
    console.log('\nFetching devices...');
    const devicesRes = await request('GET', '/v1.0/iot-03/devices?page_no=1&page_size=20', token);
    console.log('Devices response:', JSON.stringify(devicesRes, null, 2));

    if (devicesRes.success && devicesRes.result && devicesRes.result.list) {
      console.log('\n=== DEVICE KEYS ===');
      for (const d of devicesRes.result.list) {
        console.log(`\nName: ${d.name}`);
        console.log(`ID:   ${d.id}`);
        console.log(`Key:  ${d.local_key}`);
        console.log(`IP:   ${d.ip || 'N/A'}`);
      }
    }

    // Also try individual device endpoint for the second cellar
    const deviceId = 'eb53160c227afdea2evnfe';
    console.log(`\nFetching device ${deviceId} directly...`);
    const devRes = await request('GET', `/v1.0/devices/${deviceId}`, token);
    console.log('Device response:', JSON.stringify(devRes, null, 2));

    if (devRes.success && devRes.result) {
      console.log(`\n>>> KEY FOR SECOND CELLAR: ${devRes.result.local_key}`);
    }
  } catch (e) {
    console.error('Error:', e.message);
  }
  process.exit(0);
})();
