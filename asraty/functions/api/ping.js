// Health check with no dependencies: GET /api/ping
module.exports = (req, res) => {
  res.setHeader("Content-Type", "application/json");
  res.end(JSON.stringify({ ok: true }));
};
