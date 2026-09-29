// تحقق حي من شكل ردود Massive قبل الاعتماد عليها (قاعدة المشروع: لا نثق بصيغة لم نلاحظها).
// الاستخدام: MASSIVE_API_KEY=... npm run check:massive   (طلبان فقط من حصة 5/دقيقة)
import { existsSync } from 'node:fs';
import { parseGroupedDaily, parseTickersPage, weekdaysBack } from '../server/massive.js';

if (existsSync('.env') && typeof process.loadEnvFile === 'function') process.loadEnvFile('.env');
const key = process.env.MASSIVE_API_KEY || process.env.POLYGON_API_KEY;
const BASE = (process.env.MASSIVE_API_BASE || 'https://api.polygon.io').replace(/\/+$/, '');
if (!key) { console.error('ضع MASSIVE_API_KEY في .env أولاً.'); process.exit(1); }

async function get(url) {
  const u = new URL(url); u.searchParams.set('apiKey', key);
  const res = await fetch(u);
  const text = await res.text();
  console.log(`\nHTTP ${res.status} ${url}`);
  console.log('أول 600 حرف من الرد الخام:\n' + text.slice(0, 600));
  return JSON.parse(text);
}

const date = weekdaysBack(Date.now() - 86400000, 1)[0]; // آخر يوم عمل قبل اليوم
const g = await get(`${BASE}/v2/aggs/grouped/locale/us/market/stocks/${date}?adjusted=true&include_otc=false`);
console.log('مفاتيح الرد:', Object.keys(g), '| مفاتيح أول صف:', g.results && g.results[0] && Object.keys(g.results[0]));
const rows = parseGroupedDaily(g);
console.log(`✔ parseGroupedDaily: ${rows.length} صف صالح (${date}). مثال:`, rows.find(r => r[0] === 'AAPL') || rows[0]);

await new Promise(r => setTimeout(r, 13000)); // حد الخطة المجانية
const t = parseTickersPage(await get(`${BASE}/v3/reference/tickers?market=stocks&type=CS&active=true&limit=1000`));
console.log(`✔ parseTickersPage: ${t.tickers.length} رمز في الصفحة الأولى، صفحة تالية: ${t.next ? 'نعم' : 'لا'}`);
