const http = require('http');
const TuyAPI = require('tuyapi');

const CELLARS = [
  {
    name: 'Wine CellR D',
    id: 'eb103f9b9dda5093b8k8ae',
    key: 'S&Fg>g;x^6*61&Fu',
    ip: '10.0.0.71',
    version: '3.5',
  },
  {
    name: 'Wine CellR G',
    id: 'eb53160c227afdea2evnfe',
    key: 'H`R3p5<_Oa4CzEpE',
    ip: '10.0.0.78',
    version: '3.5',
  },
];

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// Per-device mutex
const locks = CELLARS.map(() => ({ busy: false, queue: [] }));

function withLock(idx, fn) {
  return new Promise((resolve, reject) => {
    const lock = locks[idx];
    const run = () => {
      lock.busy = true;
      fn().then(resolve).catch(reject).finally(() => {
        lock.busy = false;
        if (lock.queue.length > 0) lock.queue.shift()();
      });
    };
    if (lock.busy) lock.queue.push(run);
    else run();
  });
}

function createDevice(cellar) {
  return new TuyAPI({
    id: cellar.id,
    key: cellar.key,
    ip: cellar.ip,
    version: cellar.version,
    issueGetOnConnect: false,
    nullPayloadOnJSONError: true,
  });
}

async function getStatus(idx) {
  return withLock(idx, async () => {
    const device = createDevice(CELLARS[idx]);

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        try { device.disconnect(); } catch (_) {}
        reject(new Error('Timeout reading status'));
      }, 8000);

      device.on('error', (err) => {
        clearTimeout(timer);
        try { device.disconnect(); } catch (_) {}
        reject(err instanceof Error ? err : new Error(String(err)));
      });

      device.on('data', (data) => {
        clearTimeout(timer);
        try { device.disconnect(); } catch (_) {}
        resolve(data);
      });

      device.find({ timeout: 3 })
        .then(() => device.connect())
        .then(() => sleep(200))
        .then(() => device.get({ schema: true }))
        .catch((err) => {
          clearTimeout(timer);
          try { device.disconnect(); } catch (_) {}
          reject(err);
        });
    });
  });
}

async function setDps(idx, dps, value) {
  return withLock(idx, async () => {
    const device = createDevice(CELLARS[idx]);

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        try { device.disconnect(); } catch (_) {}
        reject(new Error('Timeout setting DPS'));
      }, 8000);

      device.on('error', (err) => {
        clearTimeout(timer);
        try { device.disconnect(); } catch (_) {}
        reject(err instanceof Error ? err : new Error(String(err)));
      });

      device.find({ timeout: 3 })
        .then(() => device.connect())
        .then(() => sleep(200))
        .then(async () => {
          const payload = {
            protocol: 5,
            t: Math.floor(Date.now() / 1000),
            data: { dps: { [dps.toString()]: value } },
          };

          const parser = device.device.parser;
          const seqN = ++device._currentSequenceN;
          const buffer = parser.encode({
            data: payload,
            encrypted: true,
            commandByte: 13,
            sequenceN: seqN,
          });
          device._currentSequenceN++;

          await device._send(buffer);
          await sleep(300);
          clearTimeout(timer);
          try { device.disconnect(); } catch (_) {}
          resolve(true);
        })
        .catch((err) => {
          clearTimeout(timer);
          try { device.disconnect(); } catch (_) {}
          reject(err);
        });
    });
  });
}

function parseDps(raw) {
  if (!raw) return {};
  const dps = raw.dps || raw;
  return {
    power: dps['1'] === true,
    targetTemp: typeof dps['2'] === 'number' ? dps['2'] : 0,
    tempUnit: (dps['4'] ?? 'c').toString(),
    keyLock: dps['5'] === true,
    currentTemp: typeof dps['6'] === 'number' ? dps['6'] : 0,
    dps10: typeof dps['10'] === 'number' ? dps['10'] : 0,
    door: dps['101'] === true,
    topLed: (dps['102'] ?? 'OFF').toString(),
    currentTempF: typeof dps['103'] === 'number' ? dps['103'] : 0,
    targetTempF: typeof dps['104'] === 'number' ? dps['104'] : 0,
    sideLight: parseInt(dps['106']) || 0,
    sideLightColor: dps['107'] === true,
    raw: dps,
  };
}

const PORT = 8765;

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(200); res.end(); return; }

  const path = new URL(req.url, `http://${req.headers.host}`).pathname;

  try {
    if (path === '/cellars' && req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(CELLARS.map((c, i) => ({ index: i, name: c.name, ip: c.ip }))));
      return;
    }

    const statusMatch = path.match(/^\/status\/(\d+)$/);
    if (statusMatch && req.method === 'GET') {
      const idx = parseInt(statusMatch[1]);
      if (idx >= CELLARS.length) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Cellar not found' }));
        return;
      }
      const raw = await getStatus(idx);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ cellar: CELLARS[idx].name, ...parseDps(raw) }));
      return;
    }

    const setMatch = path.match(/^\/set\/(\d+)$/);
    if (setMatch && req.method === 'POST') {
      const idx = parseInt(setMatch[1]);
      if (idx >= CELLARS.length) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Cellar not found' }));
        return;
      }
      let body = '';
      for await (const chunk of req) body += chunk;
      const { dps, value } = JSON.parse(body);
      console.log(`SET [${idx}] ${CELLARS[idx].name} dps=${dps} value=${JSON.stringify(value)}`);

      await setDps(idx, dps, value);
      console.log(`  -> OK`);

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, cellar: CELLARS[idx].name, set: { dps, value } }));
      return;
    }

    if (path === '/status-all' && req.method === 'GET') {
      const results = await Promise.all(CELLARS.map(async (c, i) => {
        try {
          const raw = await getStatus(i);
          return { index: i, cellar: c.name, ...parseDps(raw) };
        } catch (e) {
          console.log(`  [${i}] error: ${e.message}`);
          return { index: i, cellar: c.name, error: e.message };
        }
      }));
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(results));
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  } catch (e) {
    console.log(`500: ${e.message}`);
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: e.message || 'Unknown error' }));
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Tuya bridge running on http://localhost:${PORT}`);
  console.log(`Cellars: ${CELLARS.map((c, i) => `[${i}] ${c.name} @ ${c.ip}`).join(', ')}`);
});
