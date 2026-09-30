// One-off diagnostic: signs in as each family owner and calls addTask on the
// deployed server, printing only status codes and error codes (no personal data).
// Any task it manages to create is deleted right away.
import { initializeApp, cert } from "firebase-admin/app";
import { readFileSync } from "node:fs";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

const { SERVER_URL, API_KEY } = process.env;
initializeApp({ credential: cert(JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, "utf8"))) });
const db = getFirestore();
const TITLE = "__diag__";

async function idToken(uid, claims) {
  const custom = await getAuth().createCustomToken(uid, claims);
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${API_KEY}`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: custom, returnSecureToken: true }),
  });
  const j = await r.json();
  if (!j.idToken) throw new Error(`sign-in failed: ${JSON.stringify(j.error?.message)}`);
  return j.idToken;
}

async function call(token, data) {
  const r = await fetch(`${SERVER_URL}/api/api`, {
    method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ data }),
  });
  return `${r.status} ${(await r.text()).slice(0, 400)}`;
}

const fams = await db.collection("families").limit(20).get();
console.log("families:", fams.size);
for (const f of fams.docs) {
  const people = (await f.ref.collection("people").get()).docs;
  console.log(`family ${f.id.slice(0, 6)}… people:`, people.map((p) => `${p.data().role}${p.data().active ? "" : "(pending)"}[${Object.keys(p.data()).sort().join(",")}]`).join(" | "));
  const owner = people.find((p) => p.data().role === "owner");
  if (!owner) continue;
  const tok = await idToken(owner.id, { familyId: f.id, role: "owner" });
  const member = people.find((p) => p.data().role === "member");
  console.log(" addTask all   →", await call(tok, { op: "addTask", title: TITLE, personId: "all", points: 1, repeat: "daily" }));
  if (member) console.log(" addTask one   →", await call(tok, { op: "addTask", title: TITLE, personId: member.id, points: 1, repeat: "daily" }));
  const made = await f.ref.collection("tasks").where("title", "==", TITLE).get();
  for (const d of made.docs) await d.ref.delete();
  console.log(" cleaned up:", made.size);
}
