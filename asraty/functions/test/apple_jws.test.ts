import { test, before } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { X509Certificate, createPrivateKey, sign } from "node:crypto";
import { looksLikeJws, verifyJws, lamhaUntil } from "../src/plan";

// A throwaway chain like Apple's (root → intermediate → leaf, ECDSA P-256), made with openssl at test time.
let dir = "";
let rootFp = "";
const run = (...a: string[]) => execFileSync("openssl", a, { cwd: dir, stdio: "pipe" });
const b64u = (o: unknown) => Buffer.from(typeof o === "string" ? o : JSON.stringify(o)).toString("base64url");
const certB64 = (f: string) => readFileSync(join(dir, f), "utf8").replace(/-----[^-]+-----|\s/g, "");

function chain(name: string, ca: boolean, parent?: { cert: string; key: string }, oid = "") {
  run("ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", `${name}.key`);
  run("req", "-new", "-key", `${name}.key`, "-subj", `/CN=${name}`, "-out", `${name}.csr`);
  const ext = join(dir, `${name}.ext`);
  require("node:fs").writeFileSync(ext, `basicConstraints=critical,CA:${ca ? "TRUE" : "FALSE"}\n${oid ? `${oid}=DER:0500\n` : ""}`);
  if (!parent) run("x509", "-req", "-in", `${name}.csr`, "-signkey", `${name}.key`, "-days", "36500", "-extfile", ext, "-out", `${name}.pem`);
  else run("x509", "-req", "-in", `${name}.csr`, "-CA", parent.cert, "-CAkey", parent.key, "-CAcreateserial", "-days", "36500", "-extfile", ext, "-out", `${name}.pem`);
}

before(() => {
  dir = mkdtempSync(join(tmpdir(), "jws-"));
  chain("root", true);
  chain("inter", true, { cert: "root.pem", key: "root.key" }, "1.2.840.113635.100.6.2.1");
  chain("leaf", false, { cert: "inter.pem", key: "inter.key" }, "1.2.840.113635.100.6.11.1");
  // The same shape without Apple's marker extensions (like an ordinary developer certificate).
  chain("plainleaf", false, { cert: "inter.pem", key: "inter.key" });
  rootFp = new X509Certificate(readFileSync(join(dir, "root.pem"))).fingerprint256;
});

function signed(payload: Record<string, unknown>, x5c?: string[], leaf = "leaf") {
  const header = b64u({ alg: "ES256", x5c: x5c ?? [certB64(`${leaf}.pem`), certB64("inter.pem"), certB64("root.pem")] });
  const body = b64u(payload);
  const sig = sign("sha256", Buffer.from(`${header}.${body}`), { key: createPrivateKey(readFileSync(join(dir, `${leaf}.key`))), dsaEncoding: "ieee-p1363" });
  return `${header}.${body}.${sig.toString("base64url")}`;
}

const tx = { productId: "lamha.monthly", originalTransactionId: "2000001", expiresDate: 1795500000000, signedDate: Date.now(), bundleId: "sa.lamha.lamha" };

test("a StoreKit 2 signed transaction chained to the pinned root gives the subscription line", () => {
  const jws = signed(tx);
  assert.ok(looksLikeJws(jws));
  const lines = verifyJws(jws, rootFp);
  assert.deepEqual(lines, [{ product_id: "lamha.monthly", expires_date_ms: 1795500000000, original_transaction_id: "2000001" }]);
  assert.equal(lamhaUntil(lines), 1795500000000);
});

test("a revoked (refunded) transaction ends at once", () => {
  assert.equal(verifyJws(signed({ ...tx, revocationDate: Date.now() }), rootFp)[0].expires_date_ms, 0);
});

test("a changed payload, a different root, or a broken chain is refused", () => {
  const jws = signed(tx);
  const [h, , s] = jws.split(".");
  assert.throws(() => verifyJws(`${h}.${b64u({ ...tx, expiresDate: 9999999999999 })}.${s}`, rootFp), /receipt-invalid/);
  assert.throws(() => verifyJws(jws, "00:11"), /receipt-invalid/, "not Apple's root");
  assert.throws(() => verifyJws(signed(tx, [certB64("leaf.pem"), certB64("root.pem")]), rootFp), /receipt-invalid/, "the intermediate is missing");
  assert.throws(() => verifyJws(signed(tx, [certB64("leaf.pem")]), rootFp), /receipt-invalid/);
});

test("a chain without Apple's receipt-signing marker (an ordinary developer certificate) is refused", () => {
  const jws = signed(tx, undefined, "plainleaf");
  assert.throws(() => verifyJws(jws, rootFp), /receipt-invalid/);
  assert.equal(verifyJws(jws, rootFp, Date.now(), false)[0].product_id, "lamha.monthly", "only the marker check refused it");
});

test("the old base64 receipt is not mistaken for a signed transaction", () => {
  assert.equal(looksLikeJws("MIIbase64receiptwithoutdots=="), false);
  assert.equal(looksLikeJws("eyJhbGciOiJFUzI1NiJ9.e30.c2ln"), true);
});
