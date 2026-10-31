#!/usr/bin/env node
// الاستخدام: node run.mjs --images <dir> --csv <expert.csv> [--out results.json] [--model gemini-2.5-flash]
// البيئة (لا مفاتيح في أي ملف):
//   GOOGLE_CLOUD_PROJECT, VERTEX_LOCATION (افتراضي us-central1)
//   VERTEX_ACCESS_TOKEN  مثال: export VERTEX_ACCESS_TOKEN=$(gcloud auth print-access-token)
//   PRICE_IN_PER_M, PRICE_OUT_PER_M  سعر المليون توكن بالدولار (لحساب التكلفة؛ بدونها تُترك فارغة)
import { readFileSync, writeFileSync } from 'node:fs';
import { join, extname } from 'node:path';
import { parseArgs } from 'node:util';
import { parseCsv, toExpertRows } from './csv.mjs';
import { byType } from './metrics.mjs';
import { PROMPTS, PROMPT_VERSION, RESPONSE_SCHEMA, validateResult } from './prompts.mjs';
import { formatReport } from './report.mjs';

const { values: a } = parseArgs({ options: {
  images: { type: 'string' }, csv: { type: 'string' }, out: { type: 'string', default: 'results.json' },
  model: { type: 'string', default: process.env.VERTEX_MODEL || 'gemini-2.5-flash' },
} });
if (!a.images || !a.csv) { console.error('مطلوب --images و --csv'); process.exit(2); }
const env = (k) => { const v = process.env[k]; if (!v) { console.error(`متغير البيئة ${k} مطلوب`); process.exit(2); } return v; };
const project = env('GOOGLE_CLOUD_PROJECT'), token = env('VERTEX_ACCESS_TOKEN');
const loc = process.env.VERTEX_LOCATION || 'us-central1';
const pIn = Number(process.env.PRICE_IN_PER_M), pOut = Number(process.env.PRICE_OUT_PER_M);
const url = `https://${loc}-aiplatform.googleapis.com/v1/projects/${project}/locations/${loc}/publishers/google/models/${a.model}:generateContent`;
const MIME = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp' };

async function analyze(type, file) {
  const body = {
    contents: [{ role: 'user', parts: [
      { inlineData: { mimeType: MIME[extname(file).toLowerCase()] || 'image/jpeg', data: readFileSync(file).toString('base64') } },
      { text: PROMPTS[type] }] }],
    generationConfig: { temperature: 0, responseMimeType: 'application/json', responseSchema: RESPONSE_SCHEMA },
  };
  const t0 = performance.now();
  const res = await fetch(url, { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const ms = performance.now() - t0;
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const j = await res.json();
  const out = validateResult(JSON.parse(j.candidates?.[0]?.content?.parts?.[0]?.text ?? 'null'));
  const u = j.usageMetadata || {};
  const cost = Number.isFinite(pIn) && Number.isFinite(pOut)
    ? ((u.promptTokenCount || 0) * pIn + (u.candidatesTokenCount || 0) * pOut) / 1e6 : NaN;
  return { score: out.status === 'ok' ? out.score : NaN, status: out.status, notes: out.notes, ms, cost };
}

const rows = toExpertRows(parseCsv(readFileSync(a.csv, 'utf8')));
for (const r of rows) {
  r.runs = [];
  for (let i = 0; i < 2; i++) {
    try { r.runs.push(await analyze(r.type, join(a.images, r.image))); }
    catch (e) { console.error(`${r.image} (تشغيل ${i + 1}): ${e.message}`); r.runs.push({ score: NaN, ms: NaN, cost: NaN, error: e.message }); }
  }
  console.error(`${r.image}: خبير ${r.expert} | ${r.runs.map((x) => x.score).join(' / ')}`);
}
const metrics = byType(rows);
writeFileSync(a.out, JSON.stringify({ promptVersion: PROMPT_VERSION, model: a.model, rows, metrics }, null, 2));
console.log(formatReport(metrics, { model: a.model, promptVersion: PROMPT_VERSION }));
