import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { getMessaging } from "firebase-admin/messaging";
import { HttpsError } from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import { Perms, Role } from "./logic";

if (!getApps().length) initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export const storage = getStorage();
export { FieldValue, Timestamp };

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
export function fail(code: string, extra: Record<string, unknown> = {}, kind: "failed-precondition" | "permission-denied" | "invalid-argument" | "not-found" | "resource-exhausted" | "unauthenticated" = "failed-precondition"): never {
  throw new HttpsError(kind, code, { code, ...extra });
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
    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body: body.length > 180 ? body.slice(0, 177) + "…" : body },
      data: { familyId: fid },
      apns: { payload: { aps: { sound: "default" } } },
      android: { priority: "high", notification: { sound: "default" } },
    });
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
    logger.warn("push failed", e);
  }
}

export async function deleteProof(path?: string | null): Promise<void> {
  if (!path) return;
  try {
    await storage.bucket().file(path).delete({ ignoreNotFound: true });
  } catch (e) {
    logger.warn("proof delete failed", path, e);
  }
}

/** Deletes a document tree (subcollections included). */
export async function deleteTree(ref: FirebaseFirestore.DocumentReference): Promise<void> {
  await db.recursiveDelete(ref);
}
