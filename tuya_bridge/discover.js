const dgram = require('dgram');
const crypto = require('crypto');

// Tuya devices broadcast UDP on ports 6666 (unencrypted) and 6667 (encrypted v3.4+)
const TUYA_UDP_KEY = Buffer.from('6c1ec8e2bb9bb59ab50b0daf649b410a', 'hex');

function decrypt34(data) {
  try {
    // v3.4+ encrypted broadcast: skip header (20 bytes), decrypt rest
    const payload = data.slice(20, data.length - 8);
    const decipher = crypto.createDecipheriv('aes-128-ecb', TUYA_UDP_KEY, null);
    let decrypted = Buffer.concat([decipher.update(payload), decipher.final()]);
    return JSON.parse(decrypted.toString('utf8'));
  } catch (e) {
    return null;
  }
}

function decrypt33(data) {
  try {
    // v3.3 unencrypted broadcast: skip header (20 bytes), take until suffix
    const payload = data.slice(20, data.length - 8);
    // Try plain JSON first
    const str = payload.toString('utf8');
    const start = str.indexOf('{');
    if (start >= 0) {
      return JSON.parse(str.slice(start));
    }
    // Try AES decrypt
    const decipher = crypto.createDecipheriv('aes-128-ecb', TUYA_UDP_KEY, null);
    let decrypted = Buffer.concat([decipher.update(payload), decipher.final()]);
    return JSON.parse(decrypted.toString('utf8'));
  } catch (e) {
    return null;
  }
}

const found = new Map();

function listen(port, label) {
  const sock = dgram.createSocket({ type: 'udp4', reuseAddr: true });

  sock.on('message', (msg, rinfo) => {
    let info = null;
    if (port === 6666) {
      info = decrypt33(msg);
    } else {
      info = decrypt34(msg);
    }

    if (info && info.gwId) {
      const key = info.gwId;
      if (!found.has(key)) {
        found.set(key, true);
        console.log(`\n[$label] Device found from ${rinfo.address}:${rinfo.port}`);
        console.log(JSON.stringify(info, null, 2));
      }
    } else if (info) {
      console.log(`\n[$label] Broadcast from ${rinfo.address}:`);
      console.log(JSON.stringify(info, null, 2));
    }
  });

  sock.on('error', (err) => {
    console.log(`[${label}] Socket error: ${err.message}`);
  });

  sock.bind(port, () => {
    sock.setBroadcast(true);
    console.log(`Listening on UDP port ${port} (${label})...`);
  });

  return sock;
}

console.log('Scanning for Tuya devices on the network...');
console.log('(will listen for 30 seconds)\n');

const s1 = listen(6666, 'v3.3 unencrypted');
const s2 = listen(6667, 'v3.4+ encrypted');

setTimeout(() => {
  s1.close();
  s2.close();
  console.log(`\n\nScan complete. Found ${found.size} device(s).`);
  process.exit(0);
}, 30000);
