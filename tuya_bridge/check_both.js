const crypto = require('crypto');
const https = require('https');
const net = require('net');

const ACCESS_ID = 'fj3v7v73dvschschp949';
const ACCESS_SECRET = 'e0bf1dccdb0641e3b4beef3f046d8715';
const HOST = 'openapi.tuyaus.com';

function sign(method, path, headers, body) {
  const t = headers['t'];
  const stringToSign = [method, crypto.createHash('sha256').update(body || '').digest('hex'), '', path].join('\n');
  const str = ACCESS_ID + (headers['access_token'] || '') + t + stringToSign;
  return crypto.createHmac('sha256', ACCESS_SECRET).update(str).digest('hex').toUpperCase();
}

function request(method, path, token, body) {
  return new Promise((resolve, reject) => {
    const t = Date.now().toString();
    const headers = { 'client_id': ACCESS_ID, 't': t, 'sign_method': 'HMAC-SHA256', 'Content-Type': 'application/json' };
    if (token) headers['access_token'] = token;
    headers['sign'] = sign(method, path, headers, body);
    const opts = { hostname: HOST, port: 443, path, method, headers };
    const req = https.request(opts, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => { try { resolve(JSON.parse(data)); } catch(e) { reject(new Error(data)); } });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

function tcpProbe(ip) {
  return new Promise((resolve) => {
    const client = new net.Socket();
    client.setTimeout(5000);
    client.connect(6668, ip, () => {
      console.log(`  ${ip}:6668 - OPEN (connected)`);
      client.destroy();
      resolve(true);
    });
    client.on('data', (d) => {
      const prefix = d.slice(0, 4).toString('hex');
      console.log(`  ${ip}:6668 - Received ${d.length} bytes, prefix: ${prefix} ${prefix === '000055aa' ? '(TUYA!)' : ''}`);
      client.destroy();
      resolve(true);
    });
    client.on('timeout', () => { console.log(`  ${ip}:6668 - TIMEOUT`); client.destroy(); resolve(false); });
    client.on('error', (e) => { console.log(`  ${ip}:6668 - ERROR: ${e.message}`); resolve(false); });
  });
}

(async () => {
  // 1. TCP probe both IPs
  console.log('=== TCP PROBE ===');
  await tcpProbe('10.0.0.71');
  await tcpProbe('10.0.0.78');

  // 2. Get both device keys from cloud
  console.log('\n=== CLOUD API ===');
  const tokenRes = await request('GET', '/v1.0/token?grant_type=1');
  if (!tokenRes.success) { console.log('Token failed:', tokenRes.msg); process.exit(1); }
  const token = tokenRes.result.access_token;

  const ids = ['eb103f9b9dda5093b8k8ae', 'eb53160c227afdea2evnfe'];
  for (const id of ids) {
    const res = await request('GET', `/v1.0/devices/${id}`, token);
    if (res.success) {
      const d = res.result;
      console.log(`\n${d.name} (${d.id})`);
      console.log(`  local_key: ${d.local_key}`);
      console.log(`  online:    ${d.online}`);
      console.log(`  ip:        ${d.ip}`);
      console.log(`  model:     ${d.model}`);
      console.log(`  category:  ${d.category}`);
      console.log(`  uuid:      ${d.uuid}`);
    } else {
      console.log(`\n${id}: ${res.msg}`);
    }
  }

  // 3. Try to reset the key for the second device via cloud
  console.log('\n=== TRYING FACTORY INFO ===');
  const factoryRes = await request('GET', `/v1.0/devices/factory-infos?device_ids=eb53160c227afdea2evnfe`, token);
  console.log(JSON.stringify(factoryRes, null, 2));

  process.exit(0);
})();
