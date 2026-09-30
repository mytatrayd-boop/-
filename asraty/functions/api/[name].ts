// Vercel serverless function: POST /api/<requestCode|verifyCode|api|sendFeedback>
import { handleCall } from "../src/http";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export default async function handler(req: any, res: any) {
  const name = String(req.query?.name ?? "");
  const out = await handleCall(name, req.method, req.headers, req.body);
  res.status(out.status).setHeader("Content-Type", "application/json").send(JSON.stringify(out.body));
}
