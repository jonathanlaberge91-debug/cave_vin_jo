const { onRequest } = require("firebase-functions/v2/https");
const crypto = require("crypto");
const https = require("https");

const ACCESS_ID = "fj3v7v73dvschschp949";
const ACCESS_SECRET = "e0bf1dccdb0641e3b4beef3f046d8715";
const HOST = "openapi.tuyaus.com";

const CELLARS = [
  { name: "Wine CellR D", id: "eb103f9b9dda5093b8k8ae" },
  { name: "Wine CellR G", id: "eb53160c227afdea2evnfe" },
];

function sign(method, path, headers, body) {
  const t = headers["t"];
  const contentHash = crypto.createHash("sha256").update(body || "").digest("hex");
  const stringToSign = [method, contentHash, "", path].join("\n");
  const str = ACCESS_ID + (headers["access_token"] || "") + t + stringToSign;
  return crypto.createHmac("sha256", ACCESS_SECRET).update(str).digest("hex").toUpperCase();
}

function tuyaRequest(method, path, token, body) {
  return new Promise((resolve, reject) => {
    const t = Date.now().toString();
    const headers = {
      client_id: ACCESS_ID,
      t,
      sign_method: "HMAC-SHA256",
      "Content-Type": "application/json",
    };
    if (token) headers["access_token"] = token;
    headers["sign"] = sign(method, path, headers, body);

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

exports.tuyaProxy = onRequest({ cors: true, region: "us-east1" }, async (req, res) => {
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
      const cmdBody = JSON.stringify({ commands: [{ code, value }] });
      const r = await tuyaRequest("POST", `/v1.0/iot-03/devices/${CELLARS[idx].id}/commands`, token, cmdBody);
      if (!r.success) { res.status(500).json({ error: r.msg }); return; }
      res.json({ ok: true, cellar: CELLARS[idx].name, set: { dps, value } });
      return;
    }

    if (path === "/cellars" && req.method === "GET") {
      res.json(CELLARS.map((c, i) => ({ index: i, name: c.name })));
      return;
    }

    res.status(404).json({ error: "Not found" });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
