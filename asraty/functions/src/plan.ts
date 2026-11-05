// The family's plan: the app is free to download; the family admin (owner) subscribes, or uses a free
// activation code. The plan sets how many members the family may have (children; adults are not counted).
// The store is the only source of truth for a subscription: the owner's app sends the App Store receipt
// (iPhone) or the Google Play purchase token (Android), the server checks it with Apple (needs
// APPLE_SHARED_SECRET) or Google (needs GOOGLE_PLAY_SA_B64) and records the tier on the family.
import { createHash, createSign } from "node:crypto";
import { fail } from "./db";

/** Members every family may have, subscribed or using a free code. */
export const FREE_MEMBERS = 5;

/**
 * App Store product → members it allows. Keep in sync with app/lib/backend/access.dart.
 * One subscription group with three levels (5 / 10 / 20 members), each monthly and yearly.
 */
export const PLAN_PRODUCTS: Readonly<Record<string, number>> = {
  "asraty.monthly": 5, "asraty.yearly": 5,
  "asraty.m10": 10, "asraty.y10": 10,
  "asraty.m20": 20, "asraty.y20": 20,
};

/** Families created before the paywall launched keep using the app (their plan is marked "legacy"). */
export const LEGACY_BEFORE = Date.UTC(2026, 10, 4);

export interface FamilyPlan {
  source: "apple" | "google" | "legacy";
  tier: number;
  /** Epoch ms the subscription ends; null for legacy families. */
  until: number | null;
  productId?: string;
}

export const planActive = (p: FamilyPlan | undefined | null, now: number): boolean => !!p && (p.until == null || p.until > now);

/** How many members the family may have now (an ended subscription falls back to the free five). */
export const memberLimit = (p: FamilyPlan | undefined | null, now: number): number => Math.max(FREE_MEMBERS, planActive(p, now) ? p!.tier : 0);

/** «لمحة» (a separate app, no accounts): its subscription products. The server only tells it whether the receipt is active. */
export const LAMHA_PRODUCTS: ReadonlySet<string> = new Set(["lamha.monthly", "lamha.yearly"]);

export interface ReceiptLine {
  product_id?: string;
  expires_date_ms?: string | number;
  original_transaction_id?: string;
}

export interface FoundPlan extends FamilyPlan {
  source: "apple" | "google";
  productId: string;
  /** The store's id of the subscription (Apple's original transaction id, or a hash of Google's token): one subscription belongs to one family at a time. */
  otid: string;
}

/** The subscription that counts in a receipt: the biggest active tier, else the one that ended last. */
export function bestFromReceipt(lines: ReceiptLine[], now: number): FoundPlan | null {
  const known = lines
    .filter((l) => l.product_id && PLAN_PRODUCTS[l.product_id] && l.original_transaction_id)
    .map((l) => ({ productId: l.product_id!, tier: PLAN_PRODUCTS[l.product_id!], until: Number(l.expires_date_ms) || 0, otid: String(l.original_transaction_id) }));
  const active = known.filter((x) => x.until > now).sort((a, b) => b.tier - a.tier || b.until - a.until);
  const best = active[0] ?? known.sort((a, b) => b.until - a.until)[0];
  return best ? { source: "apple", ...best } : null;
}

export type Post = (url: string, body: unknown) => Promise<{ status?: number; latest_receipt_info?: ReceiptLine[] }>;

const post: Post = async (url, body) => (await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) })).json() as never;

/** Asks Apple about a receipt: production first, sandbox when Apple says it is a TestFlight/sandbox one (21007). */
export async function verifyReceipt(receipt: string, secret: string, send: Post = post): Promise<ReceiptLine[]> {
  const body = { "receipt-data": receipt, password: secret, "exclude-old-transactions": true };
  let r = await send("https://buy.itunes.apple.com/verifyReceipt", body);
  if (r.status === 21007) r = await send("https://sandbox.itunes.apple.com/verifyReceipt", body);
  if (r.status !== 0) fail("receipt-invalid", { status: r.status ?? -1 }, "invalid-argument");
  return r.latest_receipt_info ?? [];
}

/** When a «لمحة» subscription in the receipt ends (the latest one), or null when the receipt has none. */
export function lamhaUntil(lines: ReceiptLine[]): number | null {
  const ends = lines.filter((l) => l.product_id && LAMHA_PRODUCTS.has(l.product_id)).map((l) => Number(l.expires_date_ms) || 0);
  return ends.length ? Math.max(...ends) : null;
}

// ---------------------------------------------------------------- Google Play (Android)

/** The Android application id (Play package name). */
export const ANDROID_PACKAGE = "sa.asraty.app";

export interface PlaySubscription {
  subscriptionState?: string;
  lineItems?: { productId?: string; expiryTime?: string }[];
}

/**
 * The plan a Google Play subscription gives. ACTIVE, IN_GRACE_PERIOD and CANCELED (paid until it ends)
 * count until the expiry; ON_HOLD, PAUSED and EXPIRED do not count any more.
 */
export function planFromPlay(token: string, sub: PlaySubscription, now: number): FoundPlan | null {
  const counts = ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "SUBSCRIPTION_STATE_CANCELED"].includes(sub.subscriptionState ?? "");
  const known = (sub.lineItems ?? [])
    .filter((l) => l.productId && PLAN_PRODUCTS[l.productId] && l.expiryTime)
    .map((l) => {
      const end = Date.parse(l.expiryTime!) || 0;
      return { productId: l.productId!, tier: PLAN_PRODUCTS[l.productId!], until: counts ? end : Math.min(end, now) };
    });
  const best = known.filter((x) => x.until > now).sort((a, b) => b.tier - a.tier || b.until - a.until)[0] ?? known.sort((a, b) => b.until - a.until)[0];
  return best ? { source: "google", ...best, otid: "g:" + createHash("sha256").update(token).digest("hex").slice(0, 32) } : null;
}

export type Fetch = (url: string, init?: { method?: string; headers?: Record<string, string>; body?: string }) => Promise<{ status: number; json(): Promise<unknown> }>;

const b64u = (b: Buffer | string) => Buffer.from(b).toString("base64url");

/** An OAuth access token for the Play Developer API, from the service account JSON (signed JWT, no extra packages). */
export async function googleAccessToken(serviceAccountJson: string, send: Fetch = fetch as unknown as Fetch, nowMs = Date.now()): Promise<string> {
  const sa = JSON.parse(serviceAccountJson) as { client_email: string; private_key: string; token_uri?: string };
  const aud = sa.token_uri ?? "https://oauth2.googleapis.com/token";
  const iat = Math.floor(nowMs / 1000);
  const input = `${b64u(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${b64u(JSON.stringify({ iss: sa.client_email, scope: "https://www.googleapis.com/auth/androidpublisher", aud, iat, exp: iat + 3000 }))}`;
  const sig = createSign("RSA-SHA256").update(input).sign(sa.private_key);
  const r = await send(aud, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=${encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer")}&assertion=${input}.${b64u(sig)}`,
  });
  const j = (await r.json()) as { access_token?: string };
  if (!j.access_token) fail("plan-unavailable", { status: r.status });
  return j.access_token;
}

/** Asks Google about a purchase token (subscriptionsv2). A token Google does not know is "receipt-invalid"; a refused call (no permission) is "plan-unavailable". */
export async function verifyPlayPurchase(token: string, serviceAccountJson: string, send: Fetch = fetch as unknown as Fetch): Promise<PlaySubscription> {
  const access = await googleAccessToken(serviceAccountJson, send);
  const r = await send(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${ANDROID_PACKAGE}/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`, {
    headers: { Authorization: `Bearer ${access}` },
  });
  if (r.status === 401 || r.status === 403) fail("plan-unavailable", { status: r.status });
  if (r.status !== 200) fail("receipt-invalid", { status: r.status }, "invalid-argument");
  return (await r.json()) as PlaySubscription;
}
