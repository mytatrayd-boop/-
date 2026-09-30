// Publishes firestore.rules with the Admin SDK (uses GOOGLE_APPLICATION_CREDENTIALS).
// The Firebase Admin SDK service account may release rules, while firebase-tools
// also needs Service Usage permissions that key doesn't have.
import { readFileSync } from "node:fs";
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getSecurityRules } from "firebase-admin/security-rules";

const projectId = process.env.PROJECT_ID;
initializeApp({ credential: applicationDefault(), projectId });
const source = readFileSync(new URL("../../firestore.rules", import.meta.url), "utf8");
const ruleset = await getSecurityRules().releaseFirestoreRulesetFromSource(source);
console.log(`Firestore rules released: ${ruleset.name}`);
