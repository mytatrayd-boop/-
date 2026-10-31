import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildBody, parseResponse, makeLimiter, callGemini, endpoint, DEFAULT_MODEL } from '../gemini.mjs';
import { PROMPTS, PROMPT_VERSION, RESPONSE_SCHEMA } from '../prompts.mjs';

const good = (extra = {}) => ({
  candidates: [{ content: { parts: [{ text: JSON.stringify({ status: 'ok', score: 80, notes: ['a', 'b', 'c'], roast_level: 'dark', has_defects: false, ...extra }) }] } }],
  usageMetadata: { promptTokenCount: 300, candidatesTokenCount: 40 },
});
const resp = (status, json, headers = {}) => ({ ok: status < 400, status, json: async () => json, text: async () => JSON.stringify(json), headers: { get: (k) => headers[k.toLowerCase()] ?? null } });

test('buildBody: الطلب والمخطط وحرارة 0', () => {
  assert.equal(PROMPT_VERSION, 'v0-feasibility-2');
  const b = buildBody('bean', 'image/png', 'QUJD');
  assert.deepEqual(b.contents[0].parts[0], { inlineData: { mimeType: 'image/png', data: 'QUJD' } });
  assert.equal(b.contents[0].parts[1].text, PROMPTS.bean);
  assert.equal(b.generationConfig.temperature, 0);
  assert.equal(b.generationConfig.responseMimeType, 'application/json');
  assert.equal(b.generationConfig.responseSchema, RESPONSE_SCHEMA);
  assert.throws(() => buildBody('x', 'image/png', ''));
});

test('endpoint: Gemini API لا Vertex', () => {
  assert.equal(endpoint('m1'), 'https://generativelanguage.googleapis.com/v1beta/models/m1:generateContent');
  assert.ok(DEFAULT_MODEL.startsWith('gemini-'));
});

test('parseResponse: نتيجة وتوكنز وتكلفة 0', () => {
  const r = parseResponse(good());
  assert.equal(r.score, 80); assert.equal(r.roast, 'dark'); assert.equal(r.hasDefects, false);
  assert.equal(r.tokensIn, 300); assert.equal(r.tokensOut, 40); assert.equal(r.cost, 0);
});

test('parseResponse: unclear يعطي NaN، ورد فارغ أو غير صالح يرمي', () => {
  const u = { candidates: [{ content: { parts: [{ text: JSON.stringify({ status: 'unclear', score: 0, notes: ['', '', ''] }) }] } }] };
  assert.ok(Number.isNaN(parseResponse(u).score));
  assert.throws(() => parseResponse({ candidates: [{ finishReason: 'SAFETY' }] }), /رد فارغ/);
  assert.throws(() => parseResponse(good({ score: 150 })), /score/);
});

test('makeLimiter: فاصل أدنى بين الطلبات', async () => {
  let t = 0; const slept = [];
  const lim = makeLimiter(30, { now: () => t, sleep: async (ms) => { slept.push(ms); t += ms; } });
  await lim(); await lim(); await lim();
  assert.deepEqual(slept, [2000, 2000]);
  const off = makeLimiter(0, { now: () => 0, sleep: async () => assert.fail() });
  await off(); await off();
});

test('callGemini: 429 ثم نجاح مع backoff ومفتاح في الترويسة', async () => {
  const calls = [], slept = [];
  const seq = [resp(429, {}), resp(429, {}, { 'retry-after': '7' }), resp(200, good())];
  const out = await callGemini({ apiKey: 'K', model: 'm', body: { x: 1 }, baseDelayMs: 100,
    fetchImpl: async (url, init) => { calls.push({ url, init }); return seq.shift(); }, sleep: async (ms) => { slept.push(ms); } });
  assert.equal(out.attempts, 3);
  assert.deepEqual(slept, [100, 7000]);
  assert.equal(calls[0].init.headers['x-goog-api-key'], 'K');
  assert.ok(!calls[0].url.includes('K') && !calls[0].url.includes('key='));
  assert.ok(out.ms >= 0);
});

test('callGemini: يستسلم بعد maxRetries، و400 لا يُعاد', async () => {
  let n = 0;
  await assert.rejects(callGemini({ apiKey: 'K', model: 'm', body: {}, maxRetries: 2, fetchImpl: async () => { n++; return resp(429, {}); }, sleep: async () => {} }), /HTTP 429/);
  assert.equal(n, 3);
  n = 0;
  await assert.rejects(callGemini({ apiKey: 'K', model: 'm', body: {}, fetchImpl: async () => { n++; return resp(400, {}); }, sleep: async () => {} }), /HTTP 400/);
  assert.equal(n, 1);
});

test('callGemini: مهلة تُعاد ثم تفشل برسالة واضحة', async () => {
  const err = Object.assign(new Error('t'), { name: 'TimeoutError' });
  await assert.rejects(callGemini({ apiKey: 'K', model: 'm', body: {}, maxRetries: 1, timeoutMs: 5, fetchImpl: async () => { throw err; }, sleep: async () => {} }), /انتهت المهلة/);
});
