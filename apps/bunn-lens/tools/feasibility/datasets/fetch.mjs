#!/usr/bin/env node
// ينزّل صور اختبار الجدوى المفتوحة بلا حساب إلى ../data (مستثنى من git) ويكتب manifest.csv هنا.
// الاستخدام: node datasets/fetch.mjs [--out ../data] [--keep-cache]
// يحتاج curl وunzip. الاتصال عبر HTTPS_PROXY/CA المعدّة في البيئة (لا يتجاوز TLS).
// الاختيار حتمي (أسماء مرتبة، مسافات متساوية) فيعيد نفس الصور كل مرة.
import { spawnSync } from 'node:child_process';
import { mkdirSync, readdirSync, copyFileSync, rmSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join, dirname, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

const here = dirname(fileURLToPath(import.meta.url));
const { values: a } = parseArgs({ options: { out: { type: 'string', default: join(here, '..', 'data') }, 'keep-cache': { type: 'boolean', default: false } } });
const UA = 'BunnLensFeasibility/0.1 (feasibility test; open-licensed images only)';
const cache = join(a.out, '_cache');
const sh = (cmd, args) => { const r = spawnSync(cmd, args, { stdio: ['ignore', 'inherit', 'inherit'] }); if (r.status !== 0) throw new Error(`${cmd} فشل`); };
const natural = (x, y) => x.localeCompare(y, 'en', { numeric: true });
const spread = (arr, n) => (arr.length <= n ? arr : Array.from({ length: n }, (_, i) => arr[Math.floor((i * arr.length) / n)]));
const ls = (d) => readdirSync(d).filter((f) => /\.(jpe?g|png)$/i.test(f)).sort(natural);

const KAGGLE = {
  roast: { ref: 'gpiosenka/coffee-bean-dataset-resized-224-x-224', license: 'CC BY-SA 4.0' },
  defect: { ref: 'ardiyanto24/coffee-bean-classification-dataset', license: 'Apache-2.0' },
  drink: { ref: 'thekangaroofactory/coffee-images', license: 'Other (free use with attribution, see LICENSES.md)' },
  espresso: { ref: 'parangatsingh/espresso-image', license: 'Apache-2.0' },
};
function kaggle(k) {
  const dir = join(cache, k.ref.split('/')[1]);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
    const zip = `${dir}.zip`;
    console.error(`تنزيل ${k.ref} ...`);
    sh('curl', ['-fsSL', '--retry', '2', '-A', UA, '-o', zip, `https://www.kaggle.com/api/v1/datasets/download/${k.ref}`]);
    sh('unzip', ['-q', '-o', zip, '-d', dir]);
    rmSync(zip);
  }
  return dir;
}

const rows = [];
const imgDir = { bean: join(a.out, 'images', 'bean'), coffee: join(a.out, 'images', 'coffee') };
for (const d of Object.values(imgDir)) { rmSync(d, { recursive: true, force: true }); mkdirSync(d, { recursive: true }); }
const counters = { bean: 0, coffee: 0 };
function add(type, src, ext, meta) {
  const name = `${type}-${String(++counters[type]).padStart(3, '0')}${ext.toLowerCase()}`;
  copyFileSync(src, join(imgDir[type], name));
  rows.push({ image: name, type, expert_score: '', expert_class: '', notes_correct: '', roast_label: '', defect_label: '', clear_class: '', ...meta });
}

// بن: مستوى التحميص (حبة واحدة، 224px) 8 لكل مستوى
const roast = kaggle(KAGGLE.roast);
for (const lvl of ['Light', 'Medium', 'Dark']) {
  const d = join(roast, 'test', lvl);
  for (const f of spread(ls(d), 8)) add('bean', join(d, f), extname(f), { roast_label: lvl.toLowerCase(), source: KAGGLE.roast.ref, license: KAGGLE.roast.license, origin: `test/${lvl}/${f}` });
}
// بن: عيوب (بن أخضر غير محمص، حبة واحدة، 256px) 8 معيبة + 8 ممتازة
const defect = kaggle(KAGGLE.defect);
const dbase = join(defect, 'Deteksi Jenis Kopi', 'train');
for (const [cls, lbl] of [['defect', 'defect'], ['premium', 'ok']]) {
  for (const f of spread(ls(join(dbase, cls)), 8)) add('bean', join(dbase, cls, f), extname(f), { defect_label: lbl, source: KAGGLE.defect.ref, license: KAGGLE.defect.license, origin: `train/${cls}/${f}` });
}

// مشروب: Kaggle (إسبريسو/لونغ بلاك، 256px) 12 + 12، وصورة إسبريسو واحدة، ثم Wikimedia حتى 40
const drink = kaggle(KAGGLE.drink);
for (const cls of ['espresso', 'longblack']) {
  const d = join(drink, '256x', cls);
  for (const f of spread(ls(d), 12)) add('coffee', join(d, f), extname(f), { source: KAGGLE.drink.ref, license: KAGGLE.drink.license, origin: `256x/${cls}/${f}` });
}
const esp = kaggle(KAGGLE.espresso);
for (const f of ls(esp)) add('coffee', join(esp, f), extname(f), { source: KAGGLE.espresso.ref, license: KAGGLE.espresso.license, origin: f });

const wm = JSON.parse(readFileSync(join(here, 'wikimedia.json'), 'utf8'));
const WANT = 40;
let failed = 0;
mkdirSync(cache, { recursive: true });
for (const w of wm) {
  if (counters.coffee >= WANT) break;
  const tmp = join(cache, 'wm.jpg');
  const r = spawnSync('curl', ['-fsSL', '--max-time', '60', '-A', UA, '-o', tmp, w.thumb], { stdio: 'ignore' });
  if (r.status !== 0) { failed++; console.error(`تعذّر (غالباً 429 من Wikimedia): ${w.title}`); spawnSync('sleep', ['10']); continue; }
  add('coffee', tmp, '.jpg', { source: `commons.wikimedia.org (${w.author || 'unknown'})`, license: w.license, origin: w.page });
  spawnSync('sleep', ['6']);
}

const cols = ['image', 'type', 'expert_score', 'expert_class', 'notes_correct', 'roast_label', 'defect_label', 'clear_class', 'source', 'license', 'origin'];
const q = (v) => (/[",\n]/.test(v) ? `"${v.replaceAll('"', '""')}"` : v);
writeFileSync(join(here, 'manifest.csv'), [cols.join(','), ...rows.map((r) => cols.map((c) => q(String(r[c] ?? ''))).join(','))].join('\n') + '\n');
if (!a['keep-cache']) rmSync(cache, { recursive: true, force: true });
console.log(`بن: ${counters.bean} | مشروب: ${counters.coffee} | تعذّر Wikimedia: ${failed}`);
