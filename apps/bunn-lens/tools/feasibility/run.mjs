#!/usr/bin/env node
// الاستخدام: node run.mjs --images <dir> --csv <expert.csv> [--out results.json] [--model <name>]
// Gemini API المجاني (generativelanguage.googleapis.com). البيئة (لا مفاتيح في أي ملف):
//   GEMINI_API_KEY   اختياري: إن غاب يحقن الوكيل ترويسة Authorization (سر شبكة)
//   GEMINI_JSON_MODE schema (افتراضي) | object
//   GEMINI_MODEL     افتراضي gemini-2.5-flash
//   GEMINI_RPM       حد الطلبات بالدقيقة (افتراضي 5، 0 = بلا حد)
//   GEMINI_TIMEOUT_MS (افتراضي 60000)  GEMINI_MAX_RETRIES (افتراضي 4)  GEMINI_BACKOFF_MS (افتراضي 2000)
// التكلفة 0 دائماً (الطبقة المجانية).
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, extname } from 'node:path';
import { parseArgs } from 'node:util';
import { parseCsv, toExpertRows } from './csv.mjs';
import { byType } from './metrics.mjs';
import { PROMPT_VERSION } from './prompts.mjs';
import { formatReport } from './report.mjs';
import { DEFAULT_MODEL, MIME, buildBody, callGemini, makeLimiter, parseResponse } from './gemini.mjs';

const num = (k, d) => { const v = Number(process.env[k]); return process.env[k] !== undefined && process.env[k] !== '' && Number.isFinite(v) ? v : d; };
const { values: a } = parseArgs({ options: {
  images: { type: 'string' }, csv: { type: 'string' }, out: { type: 'string', default: 'results.json' },
  model: { type: 'string', default: process.env.GEMINI_MODEL || DEFAULT_MODEL },
} });
if (!a.images || !a.csv) { console.error('مطلوب --images و --csv'); process.exit(2); }
const apiKey = process.env.GEMINI_API_KEY;
const jsonMode = process.env.GEMINI_JSON_MODE || 'schema';
const limiter = makeLimiter(num('GEMINI_RPM', 5));
const opts = { timeoutMs: num('GEMINI_TIMEOUT_MS', 60000), maxRetries: num('GEMINI_MAX_RETRIES', 4), baseDelayMs: num('GEMINI_BACKOFF_MS', 2000) };

async function analyze(type, file) {
  const body = buildBody(type, MIME[extname(file).toLowerCase()] || 'image/jpeg', readFileSync(file).toString('base64'), { jsonMode });
  const { json, ms, attempts } = await callGemini({ apiKey, model: a.model, body, limiter, log: (m) => console.error(`  ${m}`), ...opts });
  return { ...parseResponse(json), ms, attempts };
}

// الصورة في <images>/<type>/<image> (مجلدات data/images) وإلا <images>/<image>
const imagePath = (r) => (existsSync(join(a.images, r.type, r.image)) ? join(a.images, r.type, r.image) : join(a.images, r.image));
const rows = toExpertRows(parseCsv(readFileSync(a.csv, 'utf8')));
let tIn = 0, tOut = 0;
for (const r of rows) {
  r.runs = [];
  for (let i = 0; i < 2; i++) {
    try { const x = await analyze(r.type, imagePath(r)); tIn += x.tokensIn; tOut += x.tokensOut; r.runs.push(x); }
    catch (e) { console.error(`${r.image} (تشغيل ${i + 1}): ${e.message}`); r.runs.push({ score: NaN, ms: NaN, cost: NaN, error: e.message }); }
  }
  console.error(`${r.image}: خبير ${r.expert ?? '-'} | ${r.runs.map((x) => `${x.score} (${Math.round(x.ms)}ms, ${x.tokensIn ?? '-'}/${x.tokensOut ?? '-'} tok)`).join(' / ')}`);
}
const metrics = byType(rows);
writeFileSync(a.out, JSON.stringify({ promptVersion: PROMPT_VERSION, model: a.model, tokens: { in: tIn, out: tOut }, rows, metrics }, null, 2));
console.log(formatReport(metrics, { model: a.model, promptVersion: PROMPT_VERSION }));
console.log(`التوكنز: دخل ${tIn} / خرج ${tOut} | التكلفة: 0 (الطبقة المجانية)`);
