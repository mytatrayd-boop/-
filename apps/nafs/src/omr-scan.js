// قراءة ورقة الإجابة الممسوحة (صورة رمادية) وتحويل التظليل إلى رقم سجل وإجابات.
// الخطوات: عتبة أوتسو ← إيجاد علامات الزوايا الأربع ← تحويل هندسي (homography) من مليمترات الورقة إلى بكسلات الصورة
// ← قياس نسبة السواد داخل كل دائرة (بعتبة محلية تتحمل الظلال) ← اختيار الدائرة الأغمق وكشف الفراغ والتظليل المزدوج.
import { MARKS, SHEET, idCenters, answerCenters } from './omr.js';

export const FILL_MIN = 0.5;     // أقل نسبة سواد داخل الدائرة لتُعدّ مظلَّلة
export const DOUBLE_RATIO = 0.7; // الدائرة الثانية قريبة من الأولى بهذه النسبة فأكثر ⇒ تظليل مزدوج

/** عتبة أوتسو لمدرّج رمادي 0..255. */
export function otsu(gray) {
    const hist = new Float64Array(256);
    for (let i = 0; i < gray.length; i++) hist[gray[i]]++;
    const total = gray.length;
    let sum = 0;
    for (let t = 0; t < 256; t++) sum += t * hist[t];
    let sumB = 0, wB = 0, best = 0, thr = 128;
    for (let t = 0; t < 256; t++) {
        wB += hist[t];
        if (!wB) continue;
        const wF = total - wB;
        if (!wF) break;
        sumB += t * hist[t];
        const between = wB * wF * ((sumB / wB) - ((sum - sumB) / wF)) ** 2;
        if (between > best) { best = between; thr = t; }
    }
    return thr;
}

/** مكوّنات متصلة داكنة (8-اتصال) ← [{x0,y0,x1,y1,area,cx,cy}]، مع حدّ أعلى للمساحة لتخطي الخلفيات الكبيرة. */
function components(bin, w, h, maxArea) {
    const seen = new Uint8Array(w * h);
    const out = [];
    const stack = new Int32Array(w * h);
    for (let s = 0; s < w * h; s++) {
        if (!bin[s] || seen[s]) continue;
        let sp = 0, area = 0, x0 = w, y0 = h, x1 = 0, y1 = 0, sx = 0, sy = 0;
        stack[sp++] = s; seen[s] = 1;
        while (sp) {
            const p = stack[--sp], x = p % w, y = (p - x) / w;
            area++; sx += x; sy += y;
            if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
            for (let dy = -1; dy <= 1; dy++) {
                const ny = y + dy;
                if (ny < 0 || ny >= h) continue;
                for (let dx = -1; dx <= 1; dx++) {
                    const nx = x + dx;
                    if (nx < 0 || nx >= w || (!dx && !dy)) continue;
                    const q = ny * w + nx;
                    if (bin[q] && !seen[q]) { seen[q] = 1; stack[sp++] = q; }
                }
            }
        }
        if (area <= maxArea) out.push({ x0, y0, x1, y1, area, cx: sx / area, cy: sy / area });
    }
    return out;
}

/** أربع علامات الزوايا [يسار-أعلى، يمين-أعلى، يسار-أسفل، يمين-أسفل] بمراكزها، أو null. */
export function findMarks(gray, w, h) {
    const thr = otsu(gray);
    const bin = new Uint8Array(w * h);
    for (let i = 0; i < bin.length; i++) bin[i] = gray[i] < thr ? 1 : 0;
    const maxSide = w * 0.09;
    const cands = components(bin, w, h, maxSide * maxSide).filter((c) => {
        const bw = c.x1 - c.x0 + 1, bh = c.y1 - c.y0 + 1;
        return bw >= w * 0.012 && bw <= maxSide && bh <= maxSide && bw / bh > 0.7 && bw / bh < 1.43 && c.area / (bw * bh) > 0.8;
    });
    if (cands.length < 4) return null;
    // الحجم الشائع بين المرشحين (علامات الزوايا متساوية)
    const sizes = cands.map((c) => c.x1 - c.x0 + 1).sort((a, b) => a - b);
    const med = sizes[Math.floor(sizes.length / 2)];
    const ok = cands.filter((c) => Math.abs(c.x1 - c.x0 + 1 - med) <= med * 0.35);
    if (ok.length < 4) return null;
    const pick = (fx, fy) => ok.reduce((b, c) => (Math.hypot(c.cx - fx, c.cy - fy) < Math.hypot(b.cx - fx, b.cy - fy) ? c : b));
    const m = [pick(0, 0), pick(w, 0), pick(0, h), pick(w, h)];
    if (new Set(m).size < 4) return null;
    return m.map((c) => ({ x: c.cx, y: c.cy, size: c.x1 - c.x0 + 1 }));
}

/** حل نظام خطي n×n بالحذف الغاوسي. */
function solve(A, b) {
    const n = b.length;
    for (let i = 0; i < n; i++) {
        let p = i;
        for (let r = i + 1; r < n; r++) if (Math.abs(A[r][i]) > Math.abs(A[p][i])) p = r;
        [A[i], A[p]] = [A[p], A[i]]; [b[i], b[p]] = [b[p], b[i]];
        for (let r = i + 1; r < n; r++) {
            const f = A[r][i] / A[i][i];
            for (let c = i; c < n; c++) A[r][c] -= f * A[i][c];
            b[r] -= f * b[i];
        }
    }
    const x = new Array(n).fill(0);
    for (let i = n - 1; i >= 0; i--) {
        let s = b[i];
        for (let c = i + 1; c < n; c++) s -= A[i][c] * x[c];
        x[i] = s / A[i][i];
    }
    return x;
}

/** تحويل إسقاطي من 4 نقاط مصدر إلى 4 نقاط هدف؛ يُرجع دالة (x,y) ⇒ {x,y}. */
export function homography(src, dst) {
    const A = [], b = [];
    for (let i = 0; i < 4; i++) {
        const [x, y] = src[i], [u, v] = dst[i];
        A.push([x, y, 1, 0, 0, 0, -u * x, -u * y]); b.push(u);
        A.push([0, 0, 0, x, y, 1, -v * x, -v * y]); b.push(v);
    }
    const [a, b2, c, d, e, f, g, hh] = solve(A, b);
    return (x, y) => { const k = g * x + hh * y + 1; return { x: (a * x + b2 * y + c) / k, y: (d * x + e * y + f) / k }; };
}

/** صورة تكاملية لحساب متوسط محلي سريع. */
function integral(gray, w, h) {
    const I = new Float64Array((w + 1) * (h + 1));
    for (let y = 0; y < h; y++) {
        let row = 0;
        for (let x = 0; x < w; x++) {
            row += gray[y * w + x];
            I[(y + 1) * (w + 1) + x + 1] = I[y * (w + 1) + x + 1] + row;
        }
    }
    return I;
}

/** نسبة السواد داخل دائرة (مركز px، نصف قطر px) بعتبة محلية = 0.82 × متوسط الجوار. */
function darkRatio(gray, I, w, h, cx, cy, r, win) {
    let dark = 0, total = 0;
    const x0 = Math.max(0, Math.floor(cx - r)), x1 = Math.min(w - 1, Math.ceil(cx + r));
    const y0 = Math.max(0, Math.floor(cy - r)), y1 = Math.min(h - 1, Math.ceil(cy + r));
    // متوسط الجوار الأوسع (ورق حول الدائرة) كمرجع للإضاءة
    const wx0 = Math.max(0, Math.floor(cx - win)), wx1 = Math.min(w, Math.ceil(cx + win));
    const wy0 = Math.max(0, Math.floor(cy - win)), wy1 = Math.min(h, Math.ceil(cy + win));
    const area = (wx1 - wx0) * (wy1 - wy0);
    const sum = I[wy1 * (w + 1) + wx1] - I[wy0 * (w + 1) + wx1] - I[wy1 * (w + 1) + wx0] + I[wy0 * (w + 1) + wx0];
    const ref = area ? sum / area : 255;
    // المرجع المحلي يتأثر بالحبر نفسه؛ نرفعه إلى حدّ أدنى معقول (ورق فاتح) لتفادي اعتبار ورقة داكنة كلها «مظلَّلة»
    const thr = Math.max(ref, 150) * 0.78;
    for (let y = y0; y <= y1; y++) {
        for (let x = x0; x <= x1; x++) {
            if ((x - cx) ** 2 + (y - cy) ** 2 > r * r) continue;
            total++;
            if (gray[y * w + x] < thr) dark++;
        }
    }
    return total ? dark / total : 0;
}

/** يختار الدائرة المظلَّلة من نسب سواد: {value: 0..n-1 | -1 فراغ | -2 مزدوج, ratios}. */
export function pickFilled(ratios) {
    let best = 0;
    ratios.forEach((r, i) => { if (r > ratios[best]) best = i; });
    if (ratios[best] < FILL_MIN) return -1;
    const others = ratios.filter((_, i) => i !== best);
    if (others.some((r) => r >= FILL_MIN && r >= ratios[best] * DOUBLE_RATIO)) return -2;
    return best;
}

/**
 * @param gray Uint8Array رمادي (w*h) — الصورة مقوّمة تقريباً وغير مقلوبة
 * @returns {{ok:boolean, error?:string, id?:string, idComplete?:boolean, answers?:number[], blanks?:number, multiples?:number}}
 */
export function scanSheet(gray, w, h, count) {
    const marks = findMarks(gray, w, h);
    if (!marks) return { ok: false, error: 'لم أجد علامات الزوايا الأربع. صوّر الورقة كاملة ومستقيمة وبإضاءة جيدة.' };
    const toPx = homography(MARKS, marks.map((m) => [m.x, m.y]));
    const scale = (Math.hypot(marks[1].x - marks[0].x, marks[1].y - marks[0].y) / Math.hypot(MARKS[1][0] - MARKS[0][0], MARKS[1][1] - MARKS[0][1]));
    // معقولية النسبة: عرض الورقة/ارتفاعها
    const wd = Math.hypot(marks[1].x - marks[0].x, marks[1].y - marks[0].y), ht = Math.hypot(marks[2].x - marks[0].x, marks[2].y - marks[0].y);
    const expect = (MARKS[1][0] - MARKS[0][0]) / (MARKS[2][1] - MARKS[0][1]);
    if (Math.abs(wd / ht - expect) > 0.12 * expect) return { ok: false, error: 'الورقة مائلة أو مقلوبة أو مقصوصة. صوّرها بالاتجاه الصحيح (اسم الاختبار في الأعلى).' };
    const I = integral(gray, w, h);
    const r = 1.5 * scale, win = 7 * scale;
    const sample = (p) => { const q = toPx(p.x, p.y); return darkRatio(gray, I, w, h, q.x, q.y, r, win); };

    // رقم السجل: عشر خانات، لكل خانة عشر دوائر
    const ids = idCenters();
    let id = '', idComplete = true;
    for (let i = 0; i < 10; i++) {
        const v = pickFilled(ids[i].map(sample));
        if (v >= 0) id += v; else { id += '?'; idComplete = false; }
    }
    const ans = answerCenters(count);
    const answers = [];
    let blanks = 0, multiples = 0;
    for (let q = 0; q < count; q++) {
        const v = pickFilled(ans[q].map(sample));
        if (v === -1) blanks++;
        if (v === -2) multiples++;
        answers.push(v);
    }
    return { ok: true, id, idComplete, answers, blanks, multiples };
}

export { SHEET };
