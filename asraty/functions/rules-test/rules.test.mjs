// Security rules tests. Run with: npm run test:rules (needs Java for the emulators).
import { test, before, after, beforeEach } from "node:test";
import { readFileSync } from "node:fs";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, collection, getDocs, query, where } from "firebase/firestore";

let env;
const FID = "fam1";

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-asraty",
    firestore: { rules: readFileSync(new URL("../../firestore.rules", import.meta.url), "utf8") },
  });
});
after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "families", FID), { name: "أسرة آل محمد" });
    await setDoc(doc(db, `families/${FID}/people/owner1`), { role: "owner", name: "أبو أصيل" });
    await setDoc(doc(db, `families/${FID}/people/kid1`), { role: "member", name: "أصيل" });
    await setDoc(doc(db, `families/${FID}/people/kid2`), { role: "member", name: "لمى" });
    await setDoc(doc(db, `families/${FID}/tasks/t1`), { title: "ترتيب السرير", personId: "kid1", points: 5 });
    await setDoc(doc(db, `families/${FID}/notifications/n1`), { to: "all", title: "x" });
    await setDoc(doc(db, `families/${FID}/notifications/n2`), { to: "kid2", title: "y" });
    await setDoc(doc(db, "families/fam2"), { name: "other" });
    await setDoc(doc(db, "emailIndex/a@b.c"), { familyId: FID });
    await setDoc(doc(db, "authCodes/x"), { codeHash: "h" });
  });
});

const as = (uid, familyId, role) => env.authenticatedContext(uid, { familyId, role }).firestore();

test("family members can read their family", async () => {
  const db = as("kid1", FID, "member");
  await assertSucceeds(getDoc(doc(db, "families", FID)));
  await assertSucceeds(getDoc(doc(db, `families/${FID}/tasks/t1`)));
  await assertSucceeds(getDocs(collection(db, `families/${FID}/people`)));
});

test("other families and strangers are denied", async () => {
  await assertFails(getDoc(doc(as("kid1", FID, "member"), "families/fam2")));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "families", FID)));
  // forged claim: token says fam1 but no people doc exists
  await assertFails(getDoc(doc(as("intruder", FID, "owner"), "families", FID)));
});

test("clients can never write", async () => {
  const db = as("owner1", FID, "owner");
  await assertFails(setDoc(doc(db, `families/${FID}/ledger/l1`), { personId: "kid1", delta: 100 }));
  await assertFails(updateDoc(doc(db, `families/${FID}/tasks/t1`), { points: 999 }));
  await assertFails(setDoc(doc(db, `families/${FID}/summaries/kid1_2026-09-29`), { points: 999 }));
  await assertFails(setDoc(doc(db, "families/new"), { name: "x" }));
});

test("server-only collections are hidden", async () => {
  const db = as("owner1", FID, "owner");
  await assertFails(getDoc(doc(db, "emailIndex/a@b.c")));
  await assertFails(getDoc(doc(db, "authCodes/x")));
});

test("members only see their own notifications", async () => {
  const kid = as("kid1", FID, "member");
  await assertSucceeds(getDocs(query(collection(kid, `families/${FID}/notifications`), where("to", "in", ["all", "kid1"]))));
  await assertFails(getDoc(doc(kid, `families/${FID}/notifications/n2`)));
  await assertSucceeds(getDoc(doc(as("owner1", FID, "owner"), `families/${FID}/notifications/n2`)));
});

test("proof photos are readable by the family only, never writable", async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), `families/${FID}/proofs/c1`), { data: "abc" }));
  await assertSucceeds(getDoc(doc(as("owner1", FID, "owner"), `families/${FID}/proofs/c1`)));
  await assertFails(getDoc(doc(as("x", "fam2", "owner"), `families/${FID}/proofs/c1`)));
  await assertFails(setDoc(doc(as("kid1", FID, "member"), `families/${FID}/proofs/c2`), { data: "x" }));
});
