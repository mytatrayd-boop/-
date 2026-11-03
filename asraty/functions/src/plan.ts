// The family's plan: the app is free to download; the family admin (owner) subscribes, or uses a free
// activation code. The plan sets how many members the family may have (children; adults are not counted).
// Apple is the only source of truth for a subscription: the owner's app sends the App Store receipt,
// the server checks it with Apple (needs APPLE_SHARED_SECRET) and records the tier on the family.
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
  source: "apple" | "legacy";
  tier: number;
  /** Epoch ms the subscription ends; null for legacy families. */
  until: number | null;
  productId?: string;
}

export const planActive = (p: FamilyPlan | undefined | null, now: number): boolean => !!p && (p.until == null || p.until > now);

/** How many members the family may have now (an ended subscription falls back to the free five). */
export const memberLimit = (p: FamilyPlan | undefined | null, now: number): number => Math.max(FREE_MEMBERS, planActive(p, now) ? p!.tier : 0);

export interface ReceiptLine {
  product_id?: string;
  expires_date_ms?: string | number;
  original_transaction_id?: string;
}

export interface FoundPlan extends FamilyPlan {
  source: "apple";
  productId: string;
  /** Apple's original transaction id: one subscription belongs to one family at a time. */
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
