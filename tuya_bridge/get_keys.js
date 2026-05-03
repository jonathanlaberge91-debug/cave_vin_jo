const crypto = require('crypto');
const https = require('https');

const CLIENT_ID = 'fj3v7v73dvschschp949';
const CLIENT_SECRET = 'e0bf1dccdb0641e3b4beef3f046d8715';
const BASE = 'https://openapi.tuyaus.com';

const DEVICES = [
  'eb103f9b9dda5093b8k8ae',
  'eb53160c227afdea2evnfe',
];

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const t = Date.now().toString();
    const bodyStr = body ? JSON.stringify(body) : '';
    const contentHash = crypto.createHash('sha256').update(bodyStr).digest('hex');

    let stringToSign = [method, contentHash, '', path].join('\n');
    let signStr = CLIENT_ID + (token || '') + t + stringToSign;
    const sign = crypto.createHmac('sha256', CLIENT_SECRET)
      .update(signStr).digest('hex').toUpperCase();

    const headers = {
      'client_id': CLIENT_ID,
      'sign': sign,
      'sign_method': 'HMAC-SHA256',
      't': t,
      'Content-Type': 'application/json',
    };
    if (token) headers['access_token'] = token;

    const url = new URL(BASE + path);
    const opts = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method,
      headers,
    };

    const req = https.request(opts, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch { resolve(data); }
      });
    });
    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

(async () => {
  // 1. Get token
  console.log('Getting access token...');
  const tokenRes = await request('GET', '/v1.0/token?grant_type=1');
  if (!tokenRes.success) {
    console.log('Token error:', JSON.stringify(tokenRes, null, 2));
    return;
  }
  const token = tokenRes.result.access_token;
  console.log('Token OK\n');

  // 2. Get each device
  for (const id of DEVICES) {
    console.log(`\n${'='.repeat(50)}`);
    console.log(`Device: ${id}`);
    console.log('='.repeat(50));

    const dev = await request('GET', `/v1.0/devices/${id}`, null, token);
    if (dev.success) {
      console.log(`Name:      ${dev.result.name}`);
      console.log(`Local Key: ${dev.result.local_key}`);
      console.log(`Category:  ${dev.result.category}`);
      console.log(`Online:    ${dev.result.online}`);
      console.log(`IP:        ${dev.result.ip || 'n/a'}`);
      console.log('\nFull result:');
      console.log(JSON.stringify(dev.result, null, 2));
    } else {
      console.log('Error:', JSON.stringify(dev, null, 2));
    }

    // Also get device status (DPS values)
    const status = await request('GET', `/v1.0/devices/${id}/status`, null, token);
    if (status.success) {
      console.log('\nCurrent status (DPS):');
      console.log(JSON.stringify(status.result, null, 2));
    }

    // Get device specification (available DPS definitions)
    const spec = await request('GET', `/v1.0/devices/${id}/specifications`, null, token);
    if (spec.success) {
      console.log('\nSpecifications (DPS definitions):');
      console.log(JSON.stringify(spec.result, null, 2));
    }
  }
})();
