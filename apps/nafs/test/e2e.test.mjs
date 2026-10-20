// تجربة كاملة في متصفح حقيقي على محاكيات Firebase (يشغله: npm test بعد npm run build).
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chromium } from 'playwright-core';
import XLSX from 'xlsx';

const URL_ = 'http://localhost:5000/';
// CHROME_PATH أو متصفح Playwright المثبت مسبقاً، وإلا Google Chrome الموجود في GitHub Actions.
const exe = [process.env.CHROME_PATH, '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'].find((p) => p && existsSync(p));
let browser;

before(async () => { browser = await chromium.launch({ executablePath: exe, channel: exe ? undefined : 'chrome' }); });
after(() => browser?.close());

async function closeModal(page, expect) {
    const msg = page.locator('#modalMessage');
    await msg.waitFor({ state: 'visible' });
    if (expect) await page.waitForFunction((t) => document.getElementById('modalMessage').textContent.includes(t), expect, { timeout: 15000 });
    const text = await msg.textContent();
    await page.click('#modalOk');
    return text;
}

test('المعلم يسجل ويرفع أكسل، الطالب يختبر، والبيانات تبقى بين الأجهزة', async () => {
    const email = `t${Date.now()}@example.com`;
    const dir = mkdtempSync(join(tmpdir(), 'nafs-'));
    const xlsxPath = join(dir, 'class.xlsx');
    const ws = XLSX.utils.aoa_to_sheet([['اسم الطالب', 'رقم السجل المدني'], ['فهد محمد', 2000000001], ['سارة علي', '2000000002']]);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Sheet1');
    writeFileSync(xlsxPath, XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' }));

    // الجهاز الأول: تسجيل المعلم
    const ctx1 = await browser.newContext();
    const page = await ctx1.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.goto(URL_);
    await page.click('[data-action="show-teacher-login"]');
    await page.click('#authTabSignup');
    await page.fill('#tName', 'أحمد محمد القحطاني');
    await page.fill('#tId', '1000000009');
    await page.fill('#tSchool', 'ابتدائية التجربة');
    await page.selectOption('#tClass', 'الثالث الابتدائي - أ');
    await page.fill('#signupEmail', email);
    await page.fill('#signupPassword', 'secret123');
    await page.click('#teacherSignupForm button[type=submit]');
    assert.match(await closeModal(page, 'تم إنشاء حسابك'), /تم إنشاء حسابك/);
    await page.locator('#teacherDashboardScreen').waitFor();

    // إضافة طالب يدوياً
    await page.fill('#newStudentName', 'خالد سعد');
    await page.fill('#newStudentId', '2000000003');
    await page.click('#addStudentForm button[type=submit]');
    assert.match(await closeModal(page, 'تم إضافة'), /تم إضافة الطالب/);

    // ملف بلا طلاب: لا يُحفظ
    await page.setInputFiles('#excelFile', { name: 'empty.xlsx', mimeType: 'application/octet-stream', buffer: Buffer.from('لا شيء') });
    assert.match(await closeModal(page, 'لم نجد'), /لم نجد/);
    assert.equal(await page.textContent('#uploadCount'), '0');

    // رفع الأكسل
    await page.setInputFiles('#excelFile', xlsxPath);
    assert.match(await closeModal(page, 'تم استيراد'), /تم استيراد 2 طالباً/);
    assert.equal(await page.textContent('#studentCount'), '3');
    assert.equal(await page.textContent('#uploadCount'), '1');

    // تحديث الصفحة: الدخول والبيانات باقية
    await page.reload();
    await page.locator('#teacherDashboardScreen').waitFor();
    await page.waitForFunction(() => document.getElementById('studentCount').textContent === '3');
    await page.waitForFunction(() => document.getElementById('uploadCount').textContent === '1');

    // تنزيل الملف المحفوظ
    const [download] = await Promise.all([page.waitForEvent('download'), page.click('[data-action="download-upload"]')]);
    assert.equal(download.suggestedFilename(), 'class.xlsx');

    await page.click('[data-action="logout"]');
    await closeModal(page, 'تسجيل الخروج');

    // الطالب يدخل برقمه ويختبر
    await page.click('[data-action="show-student-login"]');
    await page.fill('#sIdInput', '9999999999');
    await page.click('#studentLoginForm button[type=submit]');
    assert.match(await closeModal(page, 'غير مسجل'), /غير مسجل/);
    await page.fill('#sIdInput', '2000000001');
    await page.click('#studentLoginForm button[type=submit]');
    await page.locator('#studentDashboardScreen').waitFor();
    assert.match(await page.textContent('#studentFullNameDisplay'), /فهد محمد/);
    await page.click('[data-action="start-quiz"]');
    await page.check('input[name=q1][value=correct]');
    await page.check('input[name=q2][value=correct]');
    await page.click('[data-action="submit-quiz"]');
    assert.match(await closeModal(page, 'نتيجتك'), /100%/);

    // جهاز ثانٍ: المعلم يدخل ويرى النتيجة
    const ctx2 = await browser.newContext();
    const page2 = await ctx2.newPage();
    await page2.goto(URL_);
    await page2.click('[data-action="show-teacher-login"]');
    await page2.fill('#loginEmail', email);
    await page2.fill('#loginPassword', 'wrong-pass');
    await page2.click('#teacherLoginForm button[type=submit]');
    assert.match(await closeModal(page2, 'غير صحيحة'), /غير صحيحة/);
    await page2.fill('#loginPassword', 'secret123');
    await page2.click('#teacherLoginForm button[type=submit]');
    await page2.locator('#teacherDashboardScreen').waitFor();
    await page2.click('#tabBtnReports');
    await page2.waitForFunction(() => document.getElementById('repCompletedCount').textContent === '1');
    assert.equal(await page2.textContent('#repTotalStudents'), '3');
    assert.equal(await page2.textContent('#repAvgMastery'), '100%');

    // حذف طالب مع التأكيد
    await page2.click('#tabBtnStudents');
    await page2.locator('[data-action="delete-student"]').first().click();
    await page2.click('#modalOk');
    await page2.waitForFunction(() => document.getElementById('studentCount').textContent === '2');

    assert.deepEqual(errors, []);
    await ctx1.close();
    await ctx2.close();
});
