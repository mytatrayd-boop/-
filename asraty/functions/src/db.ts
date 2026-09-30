import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { Perms, Role, pushPayload } from "./logic";

// Outside Google Cloud (e.g. Vercel) the service account comes from an env var
// (base64 of the JSON key). Inside Cloud Functions / emulators, defaults apply.
if (!getApps().length) {
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64;
  if (b64) {
    initializeApp({ credential: cert(JSON.parse(Buffer.from(b64, "base64").toString("utf8"))) });
  } else {
    initializeApp(process.env.GCLOUD_PROJECT ? { projectId: process.env.GCLOUD_PROJECT } : undefined);
  }
}

export const db = getFirestore();
export const auth = getAuth();
export { FieldValue, Timestamp };

export type ErrorKind =
  | "failed-precondition" | "permission-denied" | "invalid-argument"
  | "not-found" | "resource-exhausted" | "unauthenticated" | "internal";

/** Error with a machine code the app maps to an Arabic message. */
export class ApiError extends Error {
  constructor(public readonly code: string, public readonly kind: ErrorKind, public readonly details: Record<string, unknown>) {
    super(code);
  }
}

export interface Person {
  id: string;
  name: string;
  email: string;
  role: Role;
  perms: Perms;
  avatar: string;
  status: "invited" | "active";
  authUid?: string | null;
  fcmTokens?: string[];
}

export const fam = (fid: string) => db.collection("families").doc(fid);
export const people = (fid: string) => fam(fid).collection("people");

/** Error with a machine code the app maps to an Arabic message. */
export function fail(code: string, extra: Record<string, unknown> = {}, kind: ErrorKind = "failed-precondition"): never {
  throw new ApiError(code, kind, { code, ...extra });
}

/** Who is calling: from a verified Firebase ID token, if any. */
export interface CallContext {
  uid?: string;
  familyId?: string;
  ip?: string;
}

export async function getPeople(fid: string): Promise<Person[]> {
  const snap = await people(fid).get();
  return snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Person, "id">) }));
}

/** Sends a push notification to the given people (best effort). */
export async function push(fid: string, targets: Person[], title: string, body: string): Promise<void> {
  const tokens = targets.flatMap((p) => p.fcmTokens ?? []);
  if (!tokens.length) return;
  try {
    const res = await getMessaging().sendEachForMulticast({ tokens, ...pushPayload(title, body, fid) });
    // Drop tokens that are no longer valid.
    const dead: string[] = [];
    res.responses.forEach((r, i) => {
      const code = r.error?.code ?? "";
      if (code.includes("registration-token-not-registered") || code.includes("invalid-argument")) dead.push(tokens[i]);
    });
    if (dead.length) {
      await Promise.all(
        targets
          .filter((p) => (p.fcmTokens ?? []).some((t) => dead.includes(t)))
          .map((p) => people(fid).doc(p.id).update({ fcmTokens: FieldValue.arrayRemove(...dead) })),
      );
    }
  } catch (e) {
    console.warn("push failed", e);
  }
}

/** Proof photos live in families/{fid}/proofs/{completionId} (base64 JPEG), deleted after a decision. */
export const proofRef = (fid: string, completionId: string) => fam(fid).collection("proofs").doc(completionId);

/** Deletes a document tree (subcollections included). */
export async function deleteTree(ref: FirebaseFirestore.DocumentReference): Promise<void> {
  await db.recursiveDelete(ref);
}
