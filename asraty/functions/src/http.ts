// Firebase "callable" protocol over plain HTTP, so the same handlers can run on
// any Node host (Netlify) and the Flutter app can call them with
// FirebaseFunctions.httpsCallableFromUri. Request: POST {data}, optional
// "Authorization: Bearer <Firebase ID token>". Response: {result} or {error}.
import { auth, ApiError, CallContext } from "./db";
import { requestCode, verifyCode } from "./authCodes";
import { api } from "./api";
import { sendFeedback } from "./feedback";

export type Handler = (data: unknown, ctx: CallContext) => Promise<unknown>;

export const handlers: Record<string, Handler> = { requestCode, verifyCode, api, sendFeedback };

const STATUS: Record<string, [string, number]> = {
  "invalid-argument": ["INVALID_ARGUMENT", 400],
  "failed-precondition": ["FAILED_PRECONDITION", 400],
  unauthenticated: ["UNAUTHENTICATED", 401],
  "permission-denied": ["PERMISSION_DENIED", 403],
  "not-found": ["NOT_FOUND", 404],
  "resource-exhausted": ["RESOURCE_EXHAUSTED", 429],
  internal: ["INTERNAL", 500],
};

export interface HttpResult {
  status: number;
  body: unknown;
}

function error(kind: string, message: string, details?: Record<string, unknown>): HttpResult {
  const [status, code] = STATUS[kind] ?? STATUS.internal;
  return { status: code, body: { error: { status, message, ...(details ? { details } : {}) } } };
}

export async function handleCall(name: string, method: string, headers: Record<string, string | string[] | undefined>, body: unknown): Promise<HttpResult> {
  const handler = Object.prototype.hasOwnProperty.call(handlers, name) ? handlers[name] : undefined;
  if (!handler) return error("not-found", "not-found");
  if (method !== "POST") return error("invalid-argument", "POST only");
  const payload = body && typeof body === "object" ? (body as { data?: unknown }).data : undefined;

  const ctx: CallContext = {};
  const fwd = headers["x-forwarded-for"];
  ctx.ip = (Array.isArray(fwd) ? fwd[0] : fwd)?.split(",")[0].trim();
  const authz = headers["authorization"];
  const token = typeof authz === "string" && authz.startsWith("Bearer ") ? authz.slice(7) : undefined;
  if (token) {
    try {
      const decoded = await auth.verifyIdToken(token);
      ctx.uid = decoded.uid;
      ctx.familyId = typeof decoded.familyId === "string" ? decoded.familyId : undefined;
    } catch {
      return error("unauthenticated", "unauthenticated", { code: "unauthenticated" });
    }
  }

  try {
    const result = await handler(payload ?? null, ctx);
    return { status: 200, body: { result: result ?? null } };
  } catch (e) {
    if (e instanceof ApiError) return error(e.kind, e.code, e.details);
    console.error(`call ${name} failed`, e);
    // A short reason lets the app show what went wrong (the family sees it in the error toast).
    const reason = String((e as Error)?.message ?? e).slice(0, 120);
    return error("internal", "internal", { code: "internal", op: String((payload as { op?: unknown })?.op ?? name), reason });
  }
}
