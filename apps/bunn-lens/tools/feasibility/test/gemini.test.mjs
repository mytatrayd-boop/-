import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildBody, parseResponse, makeLimiter, callGemini, endpoint, DEFAULT_MODEL } from '../gemini.mjs';
import { PROMPTS, PROMPT_VERSION, RESPONSE_SCHEMA } from '../prompts.mjs';

const good = (extra = {}) => ({
  choices: [{ message: { content: JSON.stringify({ status: 'ok', score: 80, notes: ['a', 'b', 'c'], roast_level: 'dark', has_defects: false, ...extra }) } }],
  usage: { prompt_tokens: 300, completion_tokens: 40 },
});
const resp = (status, json, headers = {}) => ({ ok: status < 400, status, json: async () => json, text: async () => JSON.stringify(json), headers: { get: (k) => headers[k.toLowerCase()] ?? null } });

test('buildBody: chat.completions وصورة data URL ومخطط وحرارة 0', () => {
  assert.equal(PROMPT_VERSION, 'v0-feasibility-2');
  const b = buildBody('bean', 'image/png', 'QUJD');
  const [t, im] = b.messages[0].content;
  assert.deepEqual(t, { type: 'text', text: PROMPTS.bean });
  assert.deepEqual(im, { type: 'image_url', image_url: { url: 'data:image/png;base64,QUJD' } });
  assert.equal(b.temperature, 0);
  assert.equal(b.response_format.type, 'json_schema');
  assert.equal(b.response_format.json_schema.schema.type, 'object');
  assert.equal(b.response_format.json_schema.schema.properties.score.type, 'integer');
  assert.equal(RESPONSE_SCHEMA.type, 'OBJECT');
  assert.equal(buildBody('bean', 'image/png', 'x', { jsonMode: 'object' }).response_format.type, 'json_object');
  assert.throws(() => buildBody('x', 'image/png', ''));
});

test('endpoint: نقطة التوافق مع OpenAI', () => {
  assert.equal(endpoint(), 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions');
  assert.ok(DEFAULT_MODEL.startsWith('gemini-'));
});

test('parseResponse: نتيجة وتوكنز وتكلفة 0', () => {
  const r = parseResponse(good());
  assert.equal(r.score, 80); assert.equal(r.roast, 'dark'); assert.equal(r.hasDefects, false);
  assert.equal(r.tokensIn, 300); assert.equal(r.tokensOut, 40); assert.equal(r.cost, 0);
});

test('parseResponse: unclear يعطي NaN، ورد فارغ أو غير صالح يرمي', () => {
  const u = { choices: [{ message: { content: '```json\n' + JSON.stringify({ status: 'unclear', score: 0, notes: ['', '', ''] }) + '\n```' } }] };
  assert.ok(Number.isNaN(parseResponse(u).score));
  assert.throws(() => parseResponse({ choices: [{ finish_reason: 'content_filter', message: { content: null } }] }), /رد فارغ/);
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
  assert.equal(calls[0].init.headers.Authorization, 'Bearer K');
  assert.equal(JSON.parse(calls[0].init.body).model, 'm');
  assert.ok(!calls[0].url.includes('key='));
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

test('callGemini: بلا apiKey لا ترويسة Authorization (الوكيل يحقنها)', async () => {
  let init;
  await callGemini({ model: 'm', body: {}, fetchImpl: async (u, i) => { init = i; return resp(200, good()); } });
  assert.ok(!('Authorization' in init.headers));
});
