// Local server for tests and emulator development: `node build/src/devServer.js`.
import { createServer } from "node:http";
import { handleCall } from "./http";

const port = Number(process.env.PORT ?? 5055);

createServer((req, res) => {
  let raw = "";
  req.on("data", (c) => (raw += c));
  req.on("end", async () => {
    let body: unknown = undefined;
    try {
      body = raw ? JSON.parse(raw) : undefined;
    } catch {
      body = undefined;
    }
    const name = (req.url ?? "").replace(/^\/api\//, "").split("?")[0];
    const out = await handleCall(name, req.method ?? "GET", req.headers, body);
    res.writeHead(out.status, { "Content-Type": "application/json" }).end(JSON.stringify(out.body));
  });
}).listen(port, "127.0.0.1", () => console.log(`asraty dev server on http://127.0.0.1:${port}/api/`));
