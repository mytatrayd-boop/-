// Vercel serverless function: POST /api/<requestCode|verifyCode|api|sendFeedback>
// Loads the handlers compiled by `npm run build` (tsc → build/), the same code the tests run.
let handleCall, loadError;
try {
  ({ handleCall } = require("../build/src/http.js"));
} catch (e) {
  // Surface startup problems (missing build, bad credentials) instead of a bare 500.
  loadError = e;
  console.error("asraty api failed to load", e);
}

module.exports = async (req, res) => {
  res.setHeader("Content-Type", "application/json");
  if (loadError) {
    res.statusCode = 500;
    res.end(JSON.stringify({ error: { status: "INTERNAL", message: "startup", details: { code: "startup", reason: String(loadError && loadError.message).slice(0, 300) } } }));
    return;
  }
  const name = String((req.query && req.query.name) || "");
  const out = await handleCall(name, req.method, req.headers, req.body);
  res.statusCode = out.status;
  res.end(JSON.stringify(out.body));
};
