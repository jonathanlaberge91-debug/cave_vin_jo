const http = require('http');

function set(idx, dps, value) {
  return new Promise((resolve) => {
    const data = JSON.stringify({dps, value});
    const req = http.request({hostname:'localhost', port:8765, path:'/set/'+idx, method:'POST', headers:{'Content-Type':'application/json','Content-Length':Buffer.byteLength(data)}}, res => {
      let d=''; res.on('data',c=>d+=c); res.on('end',()=>resolve(d));
    });
    req.on('error', ()=>resolve('err'));
    req.write(data); req.end();
  });
}

function getStatus(idx) {
  return new Promise((resolve) => {
    http.get('http://localhost:8765/status/'+idx, res => {
      let d=''; res.on('data',c=>d+=c); res.on('end',()=>resolve(JSON.parse(d)));
    }).on('error', ()=>resolve(null));
  });
}

(async () => {
  console.log('1. Unlock DPS 5 = false');
  await set(0, '5', false);
  await new Promise(r => setTimeout(r, 3000));

  console.log('2. Set DPS 106 = "50"');
  await set(0, '106', '50');
  await new Promise(r => setTimeout(r, 3000));

  const s = await getStatus(0);
  console.log('Result -> keyLock:', s.raw['5'], ' sideLight:', s.raw['106']);

  console.log('4. Re-lock DPS 5 = true');
  await set(0, '5', true);
  await new Promise(r => setTimeout(r, 2000));

  const s2 = await getStatus(0);
  console.log('Final -> keyLock:', s2.raw['5'], ' sideLight:', s2.raw['106']);

  process.exit(0);
})();
