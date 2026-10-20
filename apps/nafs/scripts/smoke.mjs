// تجربة حية على الرابط المنشور: معلم تجريبي يسجل ويضيف طالباً، الطالب يختبر، والمعلم يرى النتيجة.
// تُحذف بيانات التجربة في النهاية (حساب المعلم، ملفه، والطالب). يُستدعى من deploy.mjs.
import { chromium } from 'playwright-core';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

export async function smokeTest(url) {
    const email = `smoke-${Date.now()}@nafs-test.invalid`;
    const studentId = '0' + String(Math.floor(Math.random() * 1e9)).padStart(9, '0'); // السجلات الحقيقية تبدأ بـ 1 أو 2
    const browser = await chromium.launch({ channel: process.env.CHROME_PATH ? undefined : 'chrome', executablePath: process.env.CHROME_PATH });
    const errors = [];
    const ok = async (page, text) => {
        await page.waitForFunction((t) => !document.getElementById('customModal').classList.contains('hidden')
            && document.getElementById('modalMessage').textContent.includes(t), text, { timeout: 30000 });
        await page.click('#modalOk');
    };
    try {
        const page = await (await browser.newContext()).newPage();
        page.on('pageerror', (e) => errors.push(e.message));
        await page.goto(url);
        await page.click('[data-action="show-teacher-login"]');
        await page.click('#authTabSignup');
        await page.fill('#tName', 'معلم تجريبي');
        await page.fill('#tId', '1000000000');
        await page.fill('#tSchool', 'تجربة النشر');
        await page.selectOption('#tClass', { index: 1 });
        await page.fill('#signupEmail', email);
        await page.fill('#signupPassword', 'smoke-' + Math.random().toString(36).slice(2));
        await page.click('#teacherSignupForm button[type=submit]');
        await ok(page, 'تم إنشاء حسابك');
        await page.fill('#newStudentName', 'طالب تجريبي');
        await page.fill('#newStudentId', studentId);
        await page.click('#addStudentForm button[type=submit]');
        await ok(page, 'تم إضافة الطالب');
        await page.reload();
        await page.waitForFunction(() => document.getElementById('studentCount').textContent === '1', null, { timeout: 30000 });
        await page.click('[data-action="logout"]');
        await ok(page, 'تسجيل الخروج');

        await page.click('[data-action="show-student-login"]');
        await page.fill('#sIdInput', studentId);
        await page.click('#studentLoginForm button[type=submit]');
        await page.locator('#studentDashboardScreen').waitFor({ timeout: 30000 });
        await page.click('[data-action="start-quiz"]');
        await page.check('input[name=q1][value=correct]');
        await page.check('input[name=q2][value=wrong]');
        await page.click('[data-action="submit-quiz"]');
        await ok(page, '50%');
        if (errors.length) throw new Error('page errors: ' + errors.join(' | '));
        const saved = await getFirestore().doc(`students/${studentId}`).get();
        if (saved.get('score') !== 50) throw new Error('score not saved: ' + JSON.stringify(saved.data()));
    } finally {
        await browser.close();
        const db = getFirestore();
        await db.doc(`students/${studentId}`).delete().catch(() => {});
        const user = await getAuth().getUserByEmail(email).catch(() => null);
        if (user) {
            await db.recursiveDelete(db.doc(`teachers/${user.uid}`)).catch(() => {});
            await getAuth().deleteUser(user.uid);
        }
    }
}
