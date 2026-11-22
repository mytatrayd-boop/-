// تجربة حية على الرابط المنشور: معلم تجريبي يسجل ويضيف طالباً ويبني اختباراً وينشره ويضيف نموذج نافس رسمياً (بصوره)، والطالب يحلهما.
// تُحذف بيانات التجربة في النهاية (حساب المعلم، ملفه، اختباراته، والطالب ومحاولته). يُستدعى من deploy.mjs.
import { chromium } from 'playwright-core';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

export async function smokeTest(url) {
    const email = `smoke-${Date.now()}@nafs-test.invalid`;
    const studentId = '0' + String(Math.floor(Math.random() * 1e9)).padStart(9, '0'); // السجلات الحقيقية تبدأ بـ 1 أو 2
    const schoolNo = '0' + String(Math.floor(Math.random() * 1e8)).padStart(8, '0'); // مدرسة تجريبية تُحذف في النهاية
    const teacherCivil = '0' + String(Math.floor(Math.random() * 1e9)).padStart(9, '0');
    const db0 = getFirestore();
    await db0.doc(`schools/${schoolNo}`).set({ no: schoolNo, name: 'تجربة النشر', principalUid: null, principalName: null, classes: ['الثالث الابتدائي - أ'], year: '1448هـ · 2026-2027', years: [{ label: '1448هـ · 2026-2027', start: 0 }], createdAt: new Date() });
    await db0.doc(`teacherRoster/${teacherCivil}`).set({ schoolNo, name: 'معلم تجريبي', classes: ['الثالث الابتدائي - أ'], uid: null, createdAt: new Date() });
    const browser = await chromium.launch({ channel: process.env.CHROME_PATH ? undefined : 'chrome', executablePath: process.env.CHROME_PATH });
    const errors = [];
    const ok = async (page, text) => {
        await page.waitForFunction((t) => !document.getElementById('customModal').classList.contains('hidden')
            && document.getElementById('modalMessage').textContent.includes(t), text, { timeout: 30000 }).catch(async (e) => {
            throw new Error(`${e.message} — الرسالة الظاهرة: «${await page.textContent('#modalMessage').catch(() => '')}» ${errors.join(' | ')}`);
        });
        await page.click('#modalOk');
    };
    try {
        const page = await (await browser.newContext()).newPage();
        page.on('pageerror', (e) => errors.push(e.message));
        await page.goto(url);
        await page.click('[data-action="show-teacher-login"]');
        await page.click('#authTabSignup');
        await page.fill('#tId', teacherCivil);
        await page.fill('#signupEmail', email);
        await page.fill('#signupPassword', 'smoke-' + Math.random().toString(36).slice(2));
        await page.click('#teacherSignupForm button[type=submit]');
        await ok(page, 'تم تفعيل حسابك'); // تفعيل حساب معلم أضافه مدير المدرسة
        await page.fill('#newStudentName', 'طالب تجريبي');
        await page.fill('#newStudentId', studentId);
        await page.click('#addStudentForm button[type=submit]');
        await ok(page, 'تم إضافة الطالب');
        await page.reload();
        await page.waitForFunction(() => document.getElementById('studentCount').textContent === '1', null, { timeout: 30000 });
        await page.click('#tabBtnTests');
        await page.click('[data-action="new-test"]');
        await page.click('[data-action="load-template"]');
        await page.click('[data-action="save-test"][data-publish="1"]');
        await ok(page, 'نشره');
        // نموذج نافس الرسمي (رياضيات): صوره تُخدَّم من الاستضافة نفسها
        await page.click('[data-action="show-official"]');
        await page.locator('#officialList [data-action="add-official"][data-id="a3-math"]').click({ timeout: 30000 });
        await ok(page, 'أُضيف النموذج');
        await page.locator('#testsList > div', { hasText: 'الرياضيات' }).locator('[data-action="toggle-publish"]').click();
        await page.waitForFunction(() => [...document.querySelectorAll('#testsList > div')].some((d) => d.textContent.includes('الرياضيات') && d.textContent.includes('منشور')), null, { timeout: 30000 });
        await page.click('[data-action="logout"]');
        await ok(page, 'تسجيل الخروج');

        await page.click('[data-action="show-student-login"]');
        await page.fill('#sIdInput', studentId);
        await page.fill('#sPinInput', (await db0.doc(`studentPins/${studentId}`).get()).get('pin'));
        await page.click('#studentLoginForm button[type=submit]');
        const answerAll = async (title) => {
            await page.locator('#studentTestsList > div', { hasText: title }).locator('[data-action="open-test"]').click({ timeout: 30000 });
            const imgs = await page.locator('#stQuestions img').count();
            for (let i = 0; i < imgs; i++) {
                const img = page.locator('#stQuestions img').nth(i);
                await img.scrollIntoViewIfNeeded();
                await img.evaluate((el) => (el.complete && el.naturalWidth > 100 ? true : new Promise((res, rej) => { el.onload = () => res(true); el.onerror = () => rej(new Error('صورة لم تُحمَّل: ' + el.src)); })));
            }
            const n = await page.locator('#stQuestions input[type=radio]').evaluateAll((r) => new Set(r.map((x) => x.name)).size);
            for (let i = 0; i < n; i++) await page.locator(`input[name="sq-${i}"]`).first().check();
            await page.click('[data-action="submit-test"]');
            await page.click('#modalOk');
            await ok(page, 'تم إرسال');
            return { n, imgs };
        };
        const math = await answerAll('الرياضيات');
        if (math.imgs !== 8) throw new Error('math form images: ' + math.imgs);
        const reading = await answerAll('النخلة الصغيرة');
        if (errors.length) throw new Error('page errors: ' + errors.join(' | '));
        const saved = await getFirestore().collection('attempts').where('studentId', '==', studentId).get();
        const lengths = saved.docs.map((d) => d.get('answers').length).sort((a, b) => a - b);
        if (lengths.join() !== [math.n, reading.n].sort((a, b) => a - b).join()) throw new Error('attempts not saved: ' + lengths);
    } finally {
        await browser.close();
        const db = getFirestore();
        await db.doc(`students/${studentId}`).delete().catch(() => {});
        await db.doc(`studentPins/${studentId}`).delete().catch(() => {});
        const sess = await db.collection('studentSessions').where('studentId', '==', studentId).get().catch(() => ({ docs: [] }));
        await Promise.all(sess.docs.map((d) => d.ref.delete()));
        await db.doc(`teacherRoster/${teacherCivil}`).delete().catch(() => {});
        await db.doc(`schools/${schoolNo}`).delete().catch(() => {});
        const user = await getAuth().getUserByEmail(email).catch(() => null);
        if (user) {
            for (const name of ['tests', 'testKeys', 'attempts']) {
                const snap = await db.collection(name).where('teacherUid', '==', user.uid).get();
                await Promise.all(snap.docs.map((d) => d.ref.delete()));
            }
            await db.recursiveDelete(db.doc(`teachers/${user.uid}`)).catch(() => {});
            await getAuth().deleteUser(user.uid);
        }
    }
}
