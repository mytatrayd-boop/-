// «لمحة» is a separate app without accounts: its owner pays with an App Store subscription.
// The app sends the receipt here; the server asks Apple (the shared secret is the account-wide one,
// so it checks both apps) and says until when the subscription lasts. Nothing is stored.
import { createHash } from "node:crypto";
import { db, fail, Timestamp, CallContext } from "./db";
import { lamhaUntil, verifyReceipt } from "./plan";

const MAX_PER_HOUR = 30;

export async function lamhaPlan(data: unknown, ctx: CallContext) {
  const receipt = String(((data ?? {}) as { receipt?: unknown }).receipt ?? "");
  if (receipt.length < 20 || receipt.length > 3_000_000) fail("receipt-invalid", {}, "invalid-argument");
  const secret = process.env.APPLE_SHARED_SECRET;
  if (!secret) fail("plan-unavailable");

  // Per network address, so the endpoint cannot be used to hammer Apple.
  const ref = db.collection("codeTries").doc(createHash("sha256").update(`lamha|${ctx.ip ?? ""}`).digest("hex"));
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const r = (await tx.get(ref)).data();
    const start = r?.windowStart?.toMillis?.() ?? 0;
    const fresh = now - start > 3600e3;
    const n = fresh ? 0 : r?.n ?? 0;
    if (n >= MAX_PER_HOUR) fail("rate-limited", {}, "resource-exhausted");
    tx.set(ref, { n: n + 1, windowStart: fresh ? Timestamp.fromMillis(now) : r!.windowStart });
  });

  const until = lamhaUntil(await verifyReceipt(receipt, secret));
  return { active: until !== null && until > now, until };
}
