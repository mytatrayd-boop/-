// المسح الضوئي لورقة الإجابة: نرسم الورقة في متصفح، نظلّل دوائر معروفة (مع ميلان وإضاءة ضعيفة)، ثم نقرأها بالماسح.
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { chromium } from 'playwright-core';
import { omrSheetHtml, idCenters, answerCenters } from '../src/omr.js';
import { scanSheet, pickFilled } from '../src/omr-scan.js';

const exe = [process.env.CHROME_PATH, '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'].find((p) => p && existsSync(p));
let browser;
before(async () => { browser = await chromium.launch({ executablePath: exe, channel: exe ? undefined : 'chrome' }); });
after(() => browser?.close());

// يرسم الورقة ويظلل: id (نص 10 أرقام) وanswers (أرقام 0-3 أو -1 فراغ أو [i,j] تظليل مزدوج)
async function render({ count, id, answers, rotate = 0, fill = '#000', dim = 1, noise = 0 }) {
    const page = await browser.newPage({ viewport: { width: 1000, height: 1300 }, deviceScaleFactor: 1.4 });
    await page.setContent(omrSheetHtml({ title: 'اختبار', className: 'ص', subjectName: 'م', count }));
    const ids = idCenters(), ans = answerCenters(count);
    const marks = [];
    id.split('').forEach((d, i) => { if (d !== '?') marks.push(ids[i][Number(d)]); });
    answers.forEach((a, q) => { for (const j of [].concat(a)) if (j >= 0) marks.push(ans[q][j]); });
    await page.evaluate(({ marks, rotate, fill, dim }) => {
        for (const b of document.querySelectorAll('.b')) {
            const x = parseFloat(b.style.left), y = parseFloat(b.style.top);
            if (marks.some((m) => Math.abs(m.x - x) < 0.01 && Math.abs(m.y - y) < 0.01)) { b.style.background = fill; b.style.color = fill; }
        }
        const p = document.querySelector('.page');
        document.body.style.background = '#cfcfcf';
        p.style.background = '#fff';
        p.style.margin = '40px';
        p.style.transform = `rotate(${rotate}deg)`;
        p.style.transformOrigin = 'center';
        p.style.filter = `brightness(${dim})`;
    }, { marks, rotate, fill, dim });
    const png = await page.screenshot({ fullPage: true });
    const out = await page.evaluate(async (b64) => {
        const img = new Image();
        img.src = 'data:image/png;base64,' + b64;
        await img.decode();
        const c = document.createElement('canvas'); c.width = img.width; c.height = img.height;
        const g = c.getContext('2d'); g.drawImage(img, 0, 0);
        const d = g.getImageData(0, 0, c.width, c.height).data;
        const gray = new Array(c.width * c.height);
        for (let i = 0; i < gray.length; i++) gray[i] = Math.round(0.299 * d[i * 4] + 0.587 * d[i * 4 + 1] + 0.114 * d[i * 4 + 2]);
        return { w: c.width, h: c.height, gray };
    }, png.toString('base64'));
    await page.close();
    const gray = Uint8Array.from(out.gray);
    if (noise) for (let i = 0; i < gray.length; i++) gray[i] = Math.max(0, Math.min(255, gray[i] + (Math.random() - 0.5) * noise));
    return { gray, w: out.w, h: out.h };
}

test('pickFilled: فراغ ومزدوج وواحد', () => {
    assert.equal(pickFilled([0.1, 0.2, 0.15, 0.1]), -1);
    assert.equal(pickFilled([0.1, 0.9, 0.15, 0.1]), 1);
    assert.equal(pickFilled([0.8, 0.85, 0.1, 0.1]), -2);
    assert.equal(pickFilled([0.9, 0.55, 0.1, 0.1]), 0);
});

test('مسح ورقة مستقيمة: رقم السجل وأربعون إجابة بينها فراغ وتظليل مزدوج', async () => {
    const answers = Array.from({ length: 40 }, (_, i) => i % 4);
    answers[5] = -1; answers[17] = [1, 2]; answers[39] = 3;
    const { gray, w, h } = await render({ count: 40, id: '1234567890', answers });
    const r = scanSheet(gray, w, h, 40);
    assert.equal(r.ok, true, r.error);
    assert.equal(r.id, '1234567890');
    assert.equal(r.idComplete, true);
    assert.equal(r.blanks, 1);
    assert.equal(r.multiples, 1);
    answers.forEach((a, q) => assert.equal(r.answers[q], Array.isArray(a) ? -2 : a, `سؤال ${q + 1}`));
});

test('مسح ورقة مائلة 3 درجات وبإضاءة ضعيفة وتظليل بقلم رصاص ورقم ناقص', async () => {
    const answers = Array.from({ length: 25 }, (_, i) => (i * 3) % 4);
    const { gray, w, h } = await render({ count: 25, id: '10987654?1', answers, rotate: 3, fill: '#4a4a4a', dim: 0.75, noise: 20 });
    const r = scanSheet(gray, w, h, 25);
    assert.equal(r.ok, true, r.error);
    assert.equal(r.id, '10987654?1');
    assert.equal(r.idComplete, false);
    assert.deepEqual(r.answers, answers);
});

test('صورة بلا علامات زوايا ⇒ خطأ مفهوم', () => {
    const w = 400, h = 600;
    const r = scanSheet(new Uint8Array(w * h).fill(240), w, h, 20);
    assert.equal(r.ok, false);
    assert.match(r.error, /علامات الزوايا/);
});
