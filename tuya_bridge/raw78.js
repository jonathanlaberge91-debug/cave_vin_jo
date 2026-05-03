const net = require('net');

// Raw TCP connection to see what the device sends
const client = new net.Socket();
client.setTimeout(10000);

console.log('Connecting to 10.0.0.78:6668...');

client.connect(6668, '10.0.0.78', () => {
  console.log('Connected! Waiting for data...');
});

client.on('data', (data) => {
  console.log(`\nReceived ${data.length} bytes:`);
  console.log('Hex:', data.toString('hex'));
  console.log('Prefix:', data.slice(0, 4).toString('hex'));
  // Tuya prefix is 000055aa
  if (data.slice(0, 4).toString('hex') === '000055aa') {
    console.log('>> This IS a Tuya device!');
    const seqNo = data.readUInt32BE(4);
    const cmd = data.readUInt32BE(8);
    const len = data.readUInt32BE(12);
    console.log(`   Seq: ${seqNo}, Cmd: ${cmd}, Payload length: ${len}`);
  }
});

client.on('timeout', () => {
  console.log('Timeout (no data received).');
  client.destroy();
});

client.on('error', (err) => {
  console.log('Error:', err.message);
});

client.on('close', () => {
  console.log('Connection closed.');
  process.exit(0);
});

// Also try connecting to 10.0.0.71 for comparison
setTimeout(() => {
  console.log('\n---\nAlso testing 10.0.0.71:6668 for comparison...');
  const c2 = new net.Socket();
  c2.setTimeout(10000);
  c2.connect(6668, '10.0.0.71', () => {
    console.log('Connected to .71!');
  });
  c2.on('data', (d) => {
    console.log(`.71 received ${d.length} bytes, prefix: ${d.slice(0,4).toString('hex')}`);
    c2.destroy();
  });
  c2.on('timeout', () => { console.log('.71 timeout'); c2.destroy(); });
  c2.on('error', (e) => console.log('.71 error:', e.message));
  c2.on('close', () => process.exit(0));
}, 12000);
