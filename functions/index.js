const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const crypto = require("crypto");
const https = require("https");

// Secrets gérés via Firebase Secret Manager. Set via :
//   firebase functions:secrets:set TUYA_ACCESS_ID
//   firebase functions:secrets:set TUYA_ACCESS_SECRET
const TUYA_ACCESS_ID = defineSecret("TUYA_ACCESS_ID");
const TUYA_ACCESS_SECRET = defineSecret("TUYA_ACCESS_SECRET");

const HOST = "openapi.tuyaus.com";

const CELLARS = [
  { name: "Wine CellR D", id: "eb103f9b9dda5093b8k8ae" },
  { name: "Wine CellR G", id: "eb53160c227afdea2evnfe" },
];

function sign(method, path, headers, body, accessId, accessSecret) {
  const t = headers["t"];
  const contentHash = crypto.createHash("sha256").update(body || "").digest("hex");
  const stringToSign = [method, contentHash, "", path].join("\n");
  const str = accessId + (headers["access_token"] || "") + t + stringToSign;
  return crypto.createHmac("sha256", accessSecret).update(str).digest("hex").toUpperCase();
}

function tuyaRequest(method, path, token, body) {
  const accessId = TUYA_ACCESS_ID.value();
  const accessSecret = TUYA_ACCESS_SECRET.value();
  return new Promise((resolve, reject) => {
    const t = Date.now().toString();
    const headers = {
      client_id: accessId,
      t,
      sign_method: "HMAC-SHA256",
      "Content-Type": "application/json",
    };
    if (token) headers["access_token"] = token;
    headers["sign"] = sign(method, path, headers, body, accessId, accessSecret);

    const opts = { hostname: HOST, port: 443, path, method, headers };
    const req = https.request(opts, (res) => {
      let data = "";
      res.on("data", (c) => (data += c));
      res.on("end", () => {
        try { resolve(JSON.parse(data)); } catch (e) { reject(new Error(data)); }
      });
    });
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

function goveeRequest(method, path, apiKey, body) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: "openapi.api.govee.com",
      port: 443,
      path,
      method,
      headers: {
        "Govee-API-Key": apiKey,
        "Content-Type": "application/json",
      },
    };
    const req = https.request(opts, (res) => {
      let data = "";
      res.on("data", (c) => (data += c));
      res.on("end", () => {
        try { resolve(JSON.parse(data)); } catch (e) { reject(new Error(data)); }
      });
    });
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

let cachedToken = null;
let tokenExpiry = 0;

async function getToken() {
  if (cachedToken && Date.now() < tokenExpiry) return cachedToken;
  const res = await tuyaRequest("GET", "/v1.0/token?grant_type=1");
  if (!res.success) throw new Error(`Token failed: ${res.msg}`);
  cachedToken = res.result.access_token;
  tokenExpiry = Date.now() + (res.result.expire_time - 60) * 1000;
  return cachedToken;
}

const DPS_CODE_MAP = {
  "1": "switch",
  "2": "temp_set",
  "4": "temp_unit_convert",
  "5": "child_lock",
  "102": "colour_data",
  "106": "bright_value",
  "107": "temp_value",
};

function statusToDps(statusArr) {
  const codeToValue = {};
  for (const s of statusArr) codeToValue[s.code] = s.value;
  return {
    power: codeToValue["switch"] ?? false,
    targetTemp: codeToValue["temp_set"] ?? 0,
    tempUnit: (codeToValue["temp_unit_convert"] ?? "c").toString(),
    keyLock: codeToValue["child_lock"] ?? false,
    currentTemp: codeToValue["temp_current"] ?? 0,
    dps10: 0,
    door: codeToValue["doorcontact_state"] ?? false,
    topLed: (codeToValue["colour_data"] ?? "OFF").toString(),
    currentTempF: codeToValue["temp_current_f"] ?? 0,
    targetTempF: codeToValue["temp_set_f"] ?? 0,
    sideLight: parseInt(codeToValue["bright_value"]) || 0,
    sideLightColor: codeToValue["temp_value"] === true,
    raw: codeToValue,
  };
}

exports.tuyaProxy = onRequest({
  cors: [
    "https://cave-vin-jo.web.app",
    "https://cave-vin-jo.firebaseapp.com",
    /^http:\/\/localhost(:\d+)?$/,
  ],
  region: "us-east1",
  secrets: [TUYA_ACCESS_ID, TUYA_ACCESS_SECRET],
}, async (req, res) => {
  try {
    const token = await getToken();
    const path = req.path;

    if (path === "/status-all" && req.method === "GET") {
      const results = await Promise.all(
        CELLARS.map(async (c, i) => {
          try {
            const r = await tuyaRequest("GET", `/v1.0/devices/${c.id}/status`, token);
            if (!r.success) return { index: i, cellar: c.name, error: r.msg };
            return { index: i, cellar: c.name, ...statusToDps(r.result) };
          } catch (e) {
            return { index: i, cellar: c.name, error: e.message };
          }
        })
      );
      res.json(results);
      return;
    }

    const setMatch = path.match(/^\/set\/(\d+)$/);
    if (setMatch && req.method === "POST") {
      const idx = parseInt(setMatch[1]);
      if (idx >= CELLARS.length) { res.status(404).json({ error: "Cellar not found" }); return; }
      const { dps, value } = req.body;
      const code = DPS_CODE_MAP[dps] || dps;
      const supported = ["switch", "temp_set", "temp_unit_convert", "child_lock", "colour_data", "bright_value", "temp_value"];
      if (!supported.includes(code)) {
        res.status(400).json({ error: `DPS ${dps} (${code}) non supporté` });
        return;
      }

      let v = value;
      if (code === "temp_set") {
        v = parseInt(v);
        if (isNaN(v)) { res.status(400).json({ error: "Valeur température invalide" }); return; }
      } else if (code === "bright_value") {
        v = parseInt(v);
        if (isNaN(v)) { res.status(400).json({ error: "Valeur luminosité invalide" }); return; }
      } else if (code === "child_lock" || code === "switch") {
        v = Boolean(v);
      }

      const needsUnlock = ["colour_data", "bright_value", "temp_value"].includes(code);
      const delay = ms => new Promise(r => setTimeout(r, ms));

      if (needsUnlock) {
        const statusRes = await tuyaRequest("GET", `/v1.0/devices/${CELLARS[idx].id}/status`, token);
        const codeMap = {};
        if (statusRes.success) for (const s of statusRes.result) codeMap[s.code] = s.value;
        const wasLocked = codeMap["child_lock"] ?? false;

        if (wasLocked) {
          await tuyaRequest("POST", `/v1.0/iot-03/devices/${CELLARS[idx].id}/commands`, token,
            JSON.stringify({ commands: [{ code: "child_lock", value: false }] }));
          await delay(1200);
        }

        const cmdPayload = JSON.stringify({ commands: [{ code, value: v }] });
        const r = await tuyaRequest("POST", `/v1.0/iot-03/devices/${CELLARS[idx].id}/commands`, token, cmdPayload);

        if (wasLocked) {
          await delay(1200);
          await tuyaRequest("POST", `/v1.0/iot-03/devices/${CELLARS[idx].id}/commands`, token,
            JSON.stringify({ commands: [{ code: "child_lock", value: true }] }));
        }

        if (!r.success) { res.status(500).json({ error: r.msg, tuya: r }); return; }
        res.json({ ok: true, cellar: CELLARS[idx].name, set: { code, value: v } });
        return;
      }

      const cmdBody = JSON.stringify({ commands: [{ code, value: v }] });
      const r = await tuyaRequest("POST", `/v1.0/iot-03/devices/${CELLARS[idx].id}/commands`, token, cmdBody);
      if (!r.success) { res.status(500).json({ error: r.msg, tuya: r }); return; }
      res.json({ ok: true, cellar: CELLARS[idx].name, set: { code, value: v } });
      return;
    }

    if (path === "/cellars" && req.method === "GET") {
      res.json(CELLARS.map((c, i) => ({ index: i, name: c.name })));
      return;
    }

    if (path === "/debug-specs" && req.method === "GET") {
      const results = await Promise.all(
        CELLARS.map(async (c, i) => {
          try {
            const spec = await tuyaRequest("GET", `/v1.0/iot-03/devices/${c.id}/specification`, token);
            const funcs = await tuyaRequest("GET", `/v1.0/iot-03/devices/${c.id}/functions`, token);
            return { index: i, cellar: c.name, specification: spec, functions: funcs };
          } catch (e) {
            return { index: i, cellar: c.name, error: e.message };
          }
        })
      );
      res.json(results);
      return;
    }

    // ── Govee proxy ──────────────────────────────────
    if (path === "/govee/devices" && req.method === "GET") {
      const goveeKey = req.headers["x-govee-key"];
      if (!goveeKey) { res.status(400).json({ error: "Missing Govee API key" }); return; }
      try {
        const r = await goveeRequest("GET", "/router/api/v1/user/devices", goveeKey);
        if (r.code !== 200) { res.status(502).json({ error: r.msg || "Govee error" }); return; }
        const devices = (r.data || []).map(d => ({
          device: d.device,
          sku: d.sku,
          name: d.deviceName || d.device,
        }));
        res.json(devices);
      } catch (e) { res.status(502).json({ error: e.message }); }
      return;
    }

    if (path === "/govee/status" && req.method === "POST") {
      const goveeKey = req.headers["x-govee-key"];
      if (!goveeKey) { res.status(400).json({ error: "Missing Govee API key" }); return; }
      const { device, sku } = req.body;
      if (!device || !sku) { res.status(400).json({ error: "Missing device or sku" }); return; }
      try {
        const body = JSON.stringify({
          requestId: "cave-vin-" + Date.now(),
          payload: { sku, device },
        });
        const r = await goveeRequest("POST", "/router/api/v1/device/state", goveeKey, body);
        if (r.code !== 200) { res.status(502).json({ error: r.msg || "Govee error" }); return; }
        const caps = r.payload?.capabilities || [];
        const result = { online: false, temperature: null, humidity: null };
        for (const c of caps) {
          if (c.instance === "sensorTemperature") result.temperature = c.state?.value ?? null;
          if (c.instance === "sensorHumidity") result.humidity = c.state?.value ?? null;
          if (c.instance === "online") result.online = c.state?.value === true;
        }
        res.json(result);
      } catch (e) { res.status(502).json({ error: e.message }); }
      return;
    }

    res.status(404).json({ error: "Not found" });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
