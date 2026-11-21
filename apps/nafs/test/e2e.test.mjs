// تجربة كاملة في متصفح حقيقي على محاكيات Firebase (يشغله: npm test بعد npm run build).
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chromium } from 'playwright-core';
import XLSX from 'xlsx';
import { omrSheetHtml, idCenters, answerCenters } from '../src/omr.js';

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
    // صفحة التعريف باختبارات نافس
    await page.locator('#roleSelectionScreen').waitFor();
    await page.locator('#roleSelectionScreen [data-action="show-about"]').click();
    await page.locator('#aboutScreen').waitFor();
    assert.match(await page.textContent('#aboutPanelStudent'), /اقرأ.*السؤال جيداً/);
    await page.click('#aboutTabParent');
    assert.match(await page.textContent('#aboutPanelParent'), /ناقش/);
    await page.click('#aboutTabFormat');
    assert.match(await page.textContent('#aboutPanelFormat'), /45 دقيقة/);
    assert.equal(await page.locator('header img').getAttribute('alt'), 'شعار الاختبارات الوطنية نافس');
    await page.click('[data-action="back-from-about"]');
    await page.locator('#roleSelectionScreen').waitFor();
    // مدير المدرسة يسجّل نفسه بحرّية (بلا اعتماد) ومدرسته برقمها الإحصائي، ثم يضيف الفصول والمعلم
    const schoolNo = String(100000 + Math.floor(Math.random() * 899999));
    const ctxP = await browser.newContext();
    const pp = await ctxP.newPage();
    pp.on('pageerror', (e) => errors.push(e.message));
    await pp.goto(URL_);
    await pp.click('[data-action="show-principal-login"]');
    await pp.click('#pTabSignup');
    await pp.fill('#pName', 'سعد عبدالله المدير');
    await pp.fill('#pCivil', '1000000100');
    await pp.fill('#pSchool', 'ابتدائية التجربة');
    assert.equal(await pp.getAttribute('#pSchoolNo', 'pattern'), '[0-9]{3,12}'); // أرقام فقط
    await pp.fill('#pSchoolNo', schoolNo);
    await pp.fill('#pSignupEmail', `p${Date.now()}@example.com`);
    await pp.fill('#pSignupPassword', 'secret123');
    await pp.click('#principalSignupForm button[type=submit]');
    assert.match(await closeModal(pp, 'تم تسجيل'), /تم تسجيل مدرستك/);
    await pp.locator('#principalDashboardScreen').waitFor();
    assert.match(await pp.textContent('#pdMeta'), new RegExp(`ابتدائية التجربة .* ${schoolNo}`));
    await pp.check('[data-pd-class="الثالث الابتدائي - أ"]');
    await pp.check('[data-pd-class="الثالث المتوسط - أ"]');
    await pp.click('[data-action="pd-save-classes"]');
    await closeModal(pp, 'حُفظت');
    await pp.fill('#pdTName', 'أحمد محمد القحطاني');
    await pp.fill('#pdTCivil', '1000000009');
    await pp.check('[data-pd-t-class="الثالث الابتدائي - أ"]');
    await pp.check('[data-pd-t-class="الثالث المتوسط - أ"]');
    await pp.click('#pdTeacherForm button[type=submit]');
    assert.match(await closeModal(pp, 'أُضيف المعلم'), /تفعيل حسابي/);
    assert.match(await pp.textContent('#pdBody'), /لم يُفعّل حسابه/);

    // معلم لم يضفه المدير: لا يُقبل ولا يبقى له حساب
    await page.click('[data-action="show-teacher-login"]');
    await page.click('#authTabSignup');
    await page.fill('#tId', '1999999999');
    await page.fill('#signupEmail', `x${email}`);
    await page.fill('#signupPassword', 'secret123');
    await page.click('#teacherSignupForm button[type=submit]');
    assert.match(await closeModal(page, 'لم يتعرّف عليك'), /أضافه مدير مدرسته/);
    assert.equal(await page.locator('#teacherDashboardScreen').isVisible(), false);

    // المعلم المضاف يفعّل حسابه برقم سجله ويُنشئ كلمة المرور والبريد
    await page.fill('#tId', '1000000009');
    await page.fill('#signupEmail', email);
    await page.fill('#signupPassword', 'secret123');
    await page.click('#teacherSignupForm button[type=submit]');
    assert.match(await closeModal(page, 'تم تفعيل حسابك'), /تم تفعيل حسابك/);
    await page.locator('#teacherDashboardScreen').waitFor();
    assert.match(await page.textContent('#dashMeta'), /ابتدائية التجربة/);
    assert.deepEqual(await page.locator('#dashClass option').allTextContents(), ['الثالث الابتدائي (أ)', 'الثالث المتوسط (أ)']); // فصوله المسندة فقط

    // مدير جديد يسجّل بالرقم الإحصائي نفسه: تظهر تبعيتها لمدير آخر، ويرسل تنبيهاً بحذفها من عنده فتنتقل إليه
    {
        const c2 = await browser.newContext();
        const np = await c2.newPage();
        np.on('pageerror', (e) => errors.push(e.message));
        await np.goto(URL_);
        await np.click('[data-action="show-principal-login"]');
        await np.click('#pTabSignup');
        await np.fill('#pName', 'ناصر المدير الجديد');
        await np.fill('#pCivil', '1000000200');
        await np.fill('#pSchool', 'اسم آخر');
        await np.fill('#pSchoolNo', schoolNo);
        await np.fill('#pSignupEmail', `n${Date.now()}@example.com`);
        await np.fill('#pSignupPassword', 'secret123');
        await np.click('#principalSignupForm button[type=submit]');
        assert.match(await closeModal(np, 'سُجّل حسابك'), /سعد عبدالله المدير/); // اسم المدير السابق
        assert.match(await np.textContent('#pdBody'), /تتبع حالياً المدير: سعد عبدالله المدير/);
        await np.click('[data-action="pd-request-transfer"]');
        await closeModal(np, 'أُرسل التنبيه');
        await pp.reload();
        await pp.locator('[data-action="pd-approve-transfer"]').waitFor();
        assert.match(await pp.textContent('#pdBody'), /ناصر المدير الجديد/);
        await pp.click('[data-action="pd-approve-transfer"]');
        await pp.click('#modalOk'); // تأكيد
        await closeModal(pp, 'نُقلت');
        assert.match(await pp.textContent('#pdBody'), /تتبع حالياً المدير: ناصر المدير الجديد/);
        await np.click('[data-action="pd-refresh"]');
        await np.waitForFunction(() => document.getElementById('pdMeta').textContent.includes('العام الدراسي'));
        assert.match(await np.textContent('#pdBody'), /أحمد محمد القحطاني/); // معلمو المدرسة انتقلوا معها
        await c2.close();
    }

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

    // بناء اختبار من المهارات
    await page.click('#tabBtnTests');
    await page.click('[data-action="new-test"]');
    await page.click('[data-action="add-question"]');
    assert.match(await page.textContent('#tbError'), /اختر مهارة/);
    await page.fill('#tbTitle', 'اختبار المفردات والفكرة');
    await page.check('[data-skill="3-1.1"]');
    await page.check('[data-skill="3-2.1"]');
    await page.fill('#tbPassage', 'ذهب أحمد إلى الحديقة العامة في الصباح الباكر.');
    await page.click('[data-action="add-question"]');
    await page.fill('[data-q="0"][data-f="text"]', 'ضد كلمة «الباكر»:');
    for (const [j, o] of ['المتأخر', 'المبكر', 'الجميل'].entries()) await page.fill(`[data-q="0"][data-f="opt"][data-o="${j}"]`, o);
    await page.check('[data-q="0"][data-f="answer"][data-o="0"]');
    await page.click('[data-action="add-question"]');
    assert.equal(await page.inputValue('[data-q="1"][data-f="skill"]'), '3-2.1');
    await page.fill('[data-q="1"][data-f="text"]', 'أين ذهب أحمد؟');
    for (const [j, o] of ['الحديقة', 'المدرسة'].entries()) await page.fill(`[data-q="1"][data-f="opt"][data-o="${j}"]`, o);
    await page.check('[data-q="1"][data-f="answer"][data-o="0"]');
    await page.click('[data-action="save-test"][data-publish="1"]');
    assert.match(await closeModal(page, 'نشره'), /نشره/);
    await page.waitForFunction(() => document.querySelectorAll('#testsList > div').length === 1);

    // اختبار ثانٍ من النموذج الجاهز
    await page.click('[data-action="new-test"]');
    await page.click('[data-action="load-template"]');
    assert.equal(await page.inputValue('#tbTitle'), 'النخلة الصغيرة');
    assert.equal(await page.textContent('#tbCount'), '12');
    await page.click('[data-action="save-test"][data-publish="1"]');
    await closeModal(page, 'نشره');
    await page.waitForFunction(() => document.querySelectorAll('#testsList > div').length === 2);

    // نموذج نافس الرسمي (رياضيات، الصف الثالث): يُضاف مسودة ثم يُنشر
    await page.click('[data-action="show-official"]');
    await page.locator('#officialList [data-action="add-official"]').first().waitFor();
    assert.equal(await page.locator('#officialList [data-action="add-official"]').count(), 8); // عدد نماذج الثالث (رسمية + نماذج الموقع) المعروضة؛ يزداد كلما أُدرج نموذج للثالث
    await page.locator('#officialList [data-action="add-official"][data-id="a3-math"]').click();
    assert.match(await closeModal(page, 'أُضيف النموذج'), /مسودة/);
    assert.equal(await page.locator('#officialList [data-action="add-official"]').count(), 7);
    await page.locator('#testsList > div', { hasText: 'الرياضيات' }).locator('[data-action="toggle-publish"]').click();
    await page.waitForFunction(() => [...document.querySelectorAll('#testsList > div')].some((d) => d.textContent.includes('الرياضيات') && d.textContent.includes('منشور')));
    assert.equal(await page.locator('#testsList > div', { hasText: 'الرياضيات' }).locator('[data-action="edit-test"]').count(), 0);

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
    await page.waitForFunction(() => document.querySelectorAll('#studentTestsList [data-action="open-test"]').length === 3);

    await page.locator('#studentTestsList > div', { hasText: 'اختبار المفردات والفكرة' }).locator('[data-action="open-test"]').click();
    assert.match(await page.textContent('#stPassage'), /الحديقة العامة/);
    await page.locator('#stQuestions label', { hasText: 'المتأخر' }).click();
    await page.click('[data-action="submit-test"]');
    assert.match(await closeModal(page, 'السؤال 2'), /أجب عن السؤال 2/);
    await page.locator('#stQuestions label', { hasText: 'المدرسة' }).click();
    await page.click('[data-action="submit-test"]');
    await page.click('#modalOk'); // تأكيد الإرسال
    assert.match(await closeModal(page, 'تم إرسال'), /تم إرسال إجاباتك/);
    await page.waitForFunction(() => document.querySelectorAll('#studentTestsList [data-action="open-test"]').length === 2);

    await page.locator('#studentTestsList > div', { hasText: 'النخلة الصغيرة' }).locator('[data-action="open-test"]').click();
    const count = await page.locator('#stQuestions > div').count();
    for (let i = 0; i < count; i++) await page.locator(`input[name="sq-${i}"]`).first().check();
    await page.click('[data-action="submit-test"]');
    await page.click('#modalOk');
    await closeModal(page, 'تم إرسال');
    await page.waitForFunction(() => document.querySelectorAll('#studentTestsList [data-action="open-test"]').length === 1);

    // النموذج الرسمي: أسئلته صور وخياراته أ ب ج د
    await page.locator('#studentTestsList > div', { hasText: 'الرياضيات' }).locator('[data-action="open-test"]').click();
    assert.equal(await page.locator('#stQuestions img').count(), 8);
    for (let i = 0; i < 8; i++) { // الصور كسولة التحميل: نمرّر إلى كل صورة ثم ننتظر تحميلها
        const img = page.locator('#stQuestions img').nth(i);
        await img.scrollIntoViewIfNeeded();
        await img.evaluate((el) => (el.complete && el.naturalWidth > 100 ? true : new Promise((ok, no) => { el.onload = () => ok(true); el.onerror = () => no(new Error('صورة لم تُحمَّل: ' + el.src)); })));
    }
    assert.equal(await page.locator('#stQuestions label').count(), 32);
    for (let i = 0; i < 8; i++) await page.locator(`input[name="sq-${i}"]`).nth(i % 4).check();
    await page.click('[data-action="submit-test"]');
    await page.click('#modalOk');
    await closeModal(page, 'تم إرسال');
    await page.waitForFunction(() => document.querySelectorAll('#studentTestsList [data-action="open-test"]').length === 0);

    // جهاز ثانٍ: المعلم يدخل ويرى المستوى لكل مهارة
    const ctx2 = await browser.newContext({ acceptDownloads: true });
    const page2 = await ctx2.newPage();
    page2.on('pageerror', (e) => errors.push(e.message));
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
    assert.equal(await page2.textContent('#repTests'), '2'); // مادة القراءة
    assert.ok((await page2.locator('#repSkills > div').count()) === 3);
    await page2.click('[data-action="student-detail"]');
    await page2.locator('#studentModal').waitFor({ state: 'visible' });
    assert.equal(await page2.locator('#smHistory > div').count(), 2);
    assert.match(await page2.textContent('#smHistory'), /اختبار المفردات والفكرة/);
    assert.match(await page2.textContent('#smHistory > div:first-child'), /50%/);
    await page2.click('[data-action="close-student"]');
    const [csv] = await Promise.all([page2.waitForEvent('download'), page2.click('[data-action="export"]')]);
    const csvText = readFileSync(await csv.path(), 'utf8');
    assert.match(csvText, /المرادف والضد ومعنى المفردة/);
    assert.match(csvText, /فهد محمد/);
    await closeModal(page2, 'تصدير');

    await page2.click('[data-action="show-perf"]');
    await page2.locator('#perfBody img').first().waitFor();
    assert.equal(await page2.locator('#perfBody img').count(), 2); // القراءة للثالث الابتدائي: صفحتان
    assert.match(await page2.textContent('#perfTitle'), /القراءة/);
    await page2.click('[data-action="close-perf"]');

    // مادة الرياضيات: نتيجة النموذج الرسمي تظهر لكل مهارة
    await page2.click('[data-action="rep-subject"][data-id="math"]');
    assert.equal(await page2.getAttribute('[data-action="rep-subject"][data-id="math"]', 'aria-pressed'), 'true');
    assert.equal(await page2.locator('[data-action="rep-subject"]').count(), 2); // الثالث الابتدائي: بلا علوم
    await page2.waitForFunction(() => document.getElementById('repCompletedCount').textContent === '1');
    assert.equal(await page2.textContent('#repTests'), '1');
    assert.equal(await page2.locator('#repSkills > div').count(), 6);
    assert.match(await page2.textContent('#repSkills'), /القيمة المنزلية|الكسور وتمثيلها ومقارنتها/);
    assert.match(await page2.textContent('#repSkills details'), /مؤشرات لم تُقَس بعد \(37\)/);
    await page2.click('[data-action="student-detail"]');
    await page2.locator('#studentModal').waitFor({ state: 'visible' });
    assert.match(await page2.textContent('#smMeta'), /الرياضيات/);
    await page2.click('[data-action="close-student"]');
    const [csv2] = await Promise.all([page2.waitForEvent('download'), page2.click('[data-action="export"]')]);
    assert.match(readFileSync(await csv2.path(), 'utf8'), /الأنماط العددية وغير العددية/);
    await closeModal(page2, 'الرياضيات');
    await page2.click('[data-action="rep-subject"][data-id="reading"]');

    // بنك الأسئلة: إدخال يدوي ← اعتماد (بعد فحص الجودة) ← استخدامه في اختبار
    await page2.click('#tabBtnBank');
    await page2.locator('#bankSkill option').first().waitFor({ state: 'attached' });
    await page2.selectOption('#bankSubject', 'reading');
    await page2.selectOption('#bankSkill', '3-1.1');
    await page2.click('[data-action="bank-new"]');
    await page2.selectOption('#beLevel', 'know');
    await page2.fill('#beText', 'ما مرادف كلمة «سعيد» في الجملة؟');
    for (const [j, o] of ['حزين', 'فرِح', 'غاضب', 'متعب'].entries()) await page2.locator('#bankEditor .beOpt').nth(j).fill(o);
    await page2.check('#bankEditor input[name=beAns][value="1"]');
    await page2.click('[data-action="bank-save"]');
    await page2.locator('#bankList [data-action="bank-set"][data-to="approved"]').waitFor();
    assert.match(await page2.textContent('#bankList'), /تفسير الإجابة/); // ملاحظة جودة: بلا تفسير
    await page2.click('[data-action="bank-set"][data-to="approved"]');
    assert.match(await closeModal(page2, 'قبل معالجة'), /تفسير/);
    await page2.click('[data-action="bank-edit"]');
    await page2.fill('#beExplain', 'سعيد بمعنى فرِح.');
    await page2.click('[data-action="bank-save"]');
    await page2.click('[data-action="bank-set"][data-to="approved"]');
    await page2.locator('#bankList >> text=معتمد').first().waitFor();
    await page2.selectOption('#bankFilter', 'approved');
    assert.equal(await page2.textContent('#bankCount'), '1');
    // مسودات جاهزة: يختار المعلم ويعتمد بنفسه
    await page2.selectOption('#bankSkill', '3-1.2');
    await page2.click('[data-action="draft-toggle"]');
    await page2.locator('#draftList input[data-draft]').first().waitFor();
    assert.equal(await page2.locator('#draftList input[data-draft]').count(), 3);
    await page2.locator('#draftList input[data-draft]').nth(0).check();
    await page2.locator('#draftList input[data-draft]').nth(1).check();
    assert.equal(await page2.textContent('#draftSel'), '2');
    await page2.click('[data-action="draft-approve"]');
    assert.match(await closeModal(page2, 'اعتُمد 2'), /اعتُمد 2/);
    assert.equal(await page2.locator('#draftList input[data-draft]').count(), 1);
    await page2.selectOption('#bankSkill', '3-1.1');
    const imp = join(dir, 'bank.json');
    const mk = (level, text) => ({ skill: '3-1.1', level, text, options: ['نعم', 'لا', 'ربما', 'أبداً'], answer: 0, explanation: 'شرح' });
    writeFileSync(imp, JSON.stringify([mk('apply', 'سؤال التطبيق عن المرادف هنا'), { skill: '3-1.1', level: 'reason', applicable: false, reason: 'لا يناسب المؤشر' }, { skill: 'zzz', level: 'know' }, mk('know', 'ما مرادف كلمة «سعيد» في الجملة؟')]));
    await page2.setInputFiles('#bankImport', imp);
    assert.match(await closeModal(page2, 'أُضيف 2'), /تُجوهل 2/);
    await page2.selectOption('#bankFilter', 'na');
    assert.match(await page2.textContent('#bankList'), /لا يناسب المؤشر/);
    await page2.selectOption('#bankFilter', 'approved');
    assert.equal(await page2.textContent('#bankCount'), '3');
    await page2.click('#tabBtnTests');
    await page2.click('[data-action="new-test"]');
    await page2.check('[data-skill="3-1.1"]');
    await page2.click('[data-action="add-from-bank"]');
    await page2.click('[data-action="bank-use"]');
    assert.equal(await page2.inputValue('[data-q="0"][data-f="text"]'), 'ما مرادف كلمة «سعيد» في الجملة؟');
    assert.equal(await page2.locator('[data-q="0"][data-f="answer"][data-o="1"]').isChecked(), true);
    await page2.click('[data-action="cancel-test"]');

    // الاختبارات المحاكية تظهر ضمن النماذج الجاهزة
    await page2.click('#tabBtnTests');
    await page2.click('[data-action="show-official"]');
    await page2.locator('#officialList [data-action="add-official"][data-id="mock-m3a-math"]').waitFor();
    await page2.click('[data-action="add-official"][data-id="mock-m3a-math"]');
    assert.match(await closeModal(page2, 'محاكي'), /مسودة/);
    // نماذج مفتاح الموقع أُخرجت بقرار المالك: الموقع بالمفاتيح الرسمية فقط
    assert.match(await page2.textContent('#testsList'), /الاختبار المحاكي الأول/);

    // اختبار من بنك نافس الرسمي (أسئلة صور بمفاتيحها)
    await page2.click('#tabBtnTests');
    await page2.click('[data-action="show-bankpanel"]');
    await page2.locator('#bankPanel').waitFor({ state: 'visible' });
    await page2.click('[data-action="bp-subject"][data-id="math"]');
    await page2.locator('#bpSkills input[data-bp-skill="m3-1-1-2.1"]').waitFor();
    await page2.check('#bpSkills input[data-bp-skill="m3-1-1-2.1"]');
    assert.equal(await page2.textContent('#bpCount'), '5');
    await page2.uncheck('#bankPanel input[data-bp-level="reason"]');
    await page2.check('#bpSkills input[data-bp-skill="m3-1-1-2.1"]');
    await page2.click('[data-action="bp-create"]');
    assert.match(await closeModal(page2, 'أُنشئ اختبار'), /مسودة/);
    assert.match(await page2.textContent('#testsList'), /بنك نافس — الرياضيات/);

    // المسح الضوئي: ورقة إجابة مظلَّلة للطالب فهد (2000000001) على اختبار البنك، فتُصحَّح وتُعتمد وتظهر محاولته
    {
        const card = page2.locator('#testsList > div', { hasText: 'بنك نافس — الرياضيات' }).first();
        const n = Number((await card.locator('p').first().textContent()).match(/(\d+) سؤالاً/)[1]);
        const sp = await browser.newPage({ viewport: { width: 1000, height: 1300 }, deviceScaleFactor: 1.4 });
        await sp.setContent(omrSheetHtml({ title: 't', className: 'c', subjectName: 'm', count: n }));
        const ids = idCenters(), ans = answerCenters(n);
        const marks = '2000000001'.split('').map((d, i) => ids[i][Number(d)]).concat(ans.map((a) => a[0])); // كل الإجابات «أ»
        await sp.evaluate((marks) => {
            for (const b of document.querySelectorAll('.b')) {
                const x = parseFloat(b.style.left), y = parseFloat(b.style.top);
                if (marks.some((m) => Math.abs(m.x - x) < 0.01 && Math.abs(m.y - y) < 0.01)) { b.style.background = '#000'; b.style.color = '#000'; }
            }
            document.querySelector('.page').style.margin = '30px';
        }, marks);
        const png = await sp.screenshot({ fullPage: true });
        await sp.close();
        await card.locator('[data-action="scan-omr"]').click();
        await page2.locator('#omrModal').waitFor({ state: 'visible' });
        await page2.setInputFiles('#omrFiles', { name: 'ورقة-فهد.png', mimeType: 'image/png', buffer: png });
        await page2.waitForFunction(() => document.getElementById('omrResults').textContent.includes('فهد محمد'), null, { timeout: 30000 });
        assert.match(await page2.textContent('#omrResults'), /الدرجة: \d+ من \d+/);
        await page2.click('#omrApprove');
        assert.match(await closeModal(page2, 'اعتُمدت'), /1 ورقة/);
        assert.match(await page2.textContent('#testsList'), /أجاب 1 من/);
    }

    // حذف طالب مع التأكيد
    await page2.click('#tabBtnStudents');
    await page2.locator('[data-action="delete-student"]').first().click();
    await page2.click('#modalOk');
    await page2.waitForFunction(() => document.getElementById('studentCount').textContent === '2');

    // الثالث المتوسط: نماذج رسمية (أ، ب × 3 مواد) ونموذجان تدريبيان للقراءة
    await page2.selectOption('#dashClass', 'الثالث المتوسط - أ');
    await page2.click('#tabBtnTests');
    await page2.click('[data-action="show-official"]');
    await page2.locator('#officialList [data-action="add-official"]').first().waitFor();
    assert.equal(await page2.locator('#officialList [data-action="add-official"]').count(), 14);
    assert.match(await page2.textContent('#officialList'), /نماذج تدريبية/);
    await page2.locator('#officialList [data-action="add-official"][data-id="t1-reading"]').click();
    assert.match(await closeModal(page2, 'أُضيف النموذج'), /مسودة/);
    assert.match(await page2.textContent('#testsList'), /نموذج تدريبي \(1\)/);
    assert.doesNotMatch(await page2.textContent('#testsList'), /جازان/);

    assert.deepEqual(errors, []);
    await ctx1.close();
    await ctx2.close();
});
