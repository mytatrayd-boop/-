// Vercel serverless function: POST /api/<requestCode|verifyCode|api|sendFeedback>
// Loads the handlers compiled by `npm run build` (tsc → build/), the same code the tests run.
const { handleCall } = require("../build/src/http.js");

module.exports = async (req, res) => {
  const name = String((req.query && req.query.name) || "");
  const out = await handleCall(name, req.method, req.headers, req.body);
  res.statusCode = out.status;
  res.setHeader("Content-Type", "application/json");
  res.end(JSON.stringify(out.body));
};
