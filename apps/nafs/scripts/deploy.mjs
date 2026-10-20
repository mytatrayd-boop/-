// ينشر قواعد Firestore والموقع (dist/) على Firebase Hosting بمفتاح حساب الخدمة
// (GOOGLE_APPLICATION_CREDENTIALS)، ثم يتحقق أن إعدادات المشروع جاهزة.
// يستخدم واجهات REST مباشرة لأن firebase-tools يحتاج صلاحيات Service Usage لا يملكها مفتاح Admin SDK.
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import { gzipSync } from 'node:zlib';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getSecurityRules } from 'firebase-admin/security-rules';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const root = new URL('..', import.meta.url).pathname;
const credential = applicationDefault();
const projectId = process.env.PROJECT_ID || JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8')).project_id;
const site = process.env.SITE_ID || projectId;
initializeApp({ credential, projectId });

const problems = [];

async function api(method, url, body, headers = {}) {
    const { access_token } = await credential.getAccessToken();
    const res = await fetch(url, {
        method,
        headers: { Authorization: `Bearer ${access_token}`, ...(body && !(body instanceof Buffer) ? { 'Content-Type': 'application/json' } : {}), ...headers },
        body: body instanceof Buffer ? body : body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`${method} ${url} → ${res.status}: ${text.slice(0, 500)}`);
    return text ? JSON.parse(text) : {};
}

// 1) قواعد Firestore
const rules = await getSecurityRules().releaseFirestoreRulesetFromSource(readFileSync(root + 'firestore.rules', 'utf8'));
console.log(`✓ Firestore rules: ${rules.name}`);

// 2) Hosting
const HOSTING = 'https://firebasehosting.googleapis.com/v1beta1';
const firebaseJson = JSON.parse(readFileSync(root + 'firebase.json', 'utf8')).hosting;
const files = {};
const blobs = {};
for (const name of readdirSync(root + 'dist')) {
    const gz = gzipSync(readFileSync(root + 'dist/' + name), { level: 9 });
    const hash = createHash('sha256').update(gz).digest('hex');
    files['/' + name] = hash;
    blobs[hash] = gz;
}
if (!files['/index.html']) throw new Error('dist/index.html missing — run npm run build first');

const version = await api('POST', `${HOSTING}/sites/${site}/versions`, {
    config: { headers: firebaseJson.headers.map((h) => ({ glob: h.source, headers: Object.fromEntries(h.headers.map((x) => [x.key, x.value])) })) },
});
const populated = await api('POST', `${HOSTING}/${version.name}:populateFiles`, { files });
for (const hash of populated.uploadRequiredHashes || []) {
    await api('POST', `${populated.uploadUrl}/${hash}`, blobs[hash], { 'Content-Type': 'application/octet-stream' });
}
await api('PATCH', `${HOSTING}/${version.name}?update_mask=status`, { status: 'FINALIZED' });
await api('POST', `${HOSTING}/sites/${site}/releases?versionName=${version.name}`, {});
const url = `https://${site}.web.app`;
console.log(`✓ Hosting: ${url} (${Object.keys(files).length} files, ${(populated.uploadRequiredHashes || []).length} uploaded)`);

// 3) فحوصات الجاهزية
let apiKey;
try {
    const init = await (await fetch(`${url}/__/firebase/init.json`)).json();
    apiKey = init.apiKey;
    if (!apiKey) throw new Error('no apiKey');
    console.log('✓ Web app config served');
} catch {
    problems.push('لا يوجد تطبيق ويب مسجل: Firebase Console ← Project settings ← Your apps ← أيقونة </> (Web) ← سجّل التطبيق.');
}

if (apiKey) {
    const idt = (path, body) => fetch(`https://identitytoolkit.googleapis.com/v1/${path}?key=${apiKey}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', Referer: url }, body: JSON.stringify(body),
    }).then((r) => r.json());
    const anon = await idt('accounts:signUp', { returnSecureToken: true });
    if (anon.localId) {
        await getAuth().deleteUser(anon.localId);
        console.log('✓ Anonymous sign-in enabled');
    } else {
        problems.push(`دخول الطلاب (Anonymous) غير مفعل: Authentication ← Sign-in method ← Anonymous ← Enable. (${anon.error?.message})`);
    }
    const pw = await idt('accounts:signInWithPassword', { email: 'nobody@nafs.invalid', password: 'x-not-a-password', returnSecureToken: true });
    if (/OPERATION_NOT_ALLOWED|DISABLED|CONFIGURATION_NOT_FOUND/.test(pw.error?.message || '')) {
        problems.push(`دخول المعلمين (Email/Password) غير مفعل: Authentication ← Sign-in method ← Email/Password ← Enable. (${pw.error.message})`);
    } else {
        console.log('✓ Email/password sign-in enabled');
    }
}

try {
    await getFirestore().doc('teachers/__deploy_check__').get();
    console.log('✓ Firestore database exists');
} catch (err) {
    problems.push(`قاعدة البيانات Firestore غير منشأة: Firestore Database ← Create database (وضع Production). (${err.message.slice(0, 120)})`);
}

if (problems.length) {
    console.log('\n⚠️ خطوات ناقصة في Firebase Console:');
    problems.forEach((p, i) => console.log(`${i + 1}. ${p}`));
    process.exitCode = 1;
} else {
    console.log(`\n✓ الموقع جاهز: ${url}`);
}
