// Netlify Function: POST /api/<requestCode|verifyCode|api|sendFeedback>
// Same Firebase-callable protocol as src/http.ts (used by the app via httpsCallableFromUri).
import { handleCall } from "../../src/http";

export default async (req: Request, context: { params?: Record<string, string> }) => {
  const name = context?.params?.name ?? new URL(req.url).pathname.split("/").pop() ?? "";
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    body = undefined;
  }
  const headers: Record<string, string> = {};
  req.headers.forEach((v, k) => (headers[k] = v));
  if (!headers["x-forwarded-for"] && headers["x-nf-client-connection-ip"]) headers["x-forwarded-for"] = headers["x-nf-client-connection-ip"];
  const out = await handleCall(name, req.method, headers, body);
  return new Response(JSON.stringify(out.body), { status: out.status, headers: { "Content-Type": "application/json" } });
};

export const config = { path: "/api/:name" };
