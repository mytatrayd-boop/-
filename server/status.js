// إشارات الحالة (أحمر / أصفر / أخضر) لشارة الواجهة — دالة صافية، مُختبرة.
// الفكرة: المستخدم يعرف بنظرة هل الأسعار حقيقية والمزامنة شغالة، ولو لا: وش السبب ووش يسوي.
import { HISTORY_DAYS } from './massive.js';

const RANK = { green: 0, yellow: 1, red: 2 };
const worst = ls => ls.reduce((w, l) => (RANK[l.level] > RANK[w] ? l.level : w), 'green');

// أيام العمل بين آخر يوم مخزّن واليوم (بدون اليوم نفسه)
function weekdaysSince(day, now) {
  let n = 0;
  for (let t = Date.parse(day + 'T00:00:00Z') + 86400000; t < now - (now % 86400000); t += 86400000) {
    const wd = new Date(t).getUTCDay();
    if (wd !== 0 && wd !== 6) n++;
  }
  return n;
}

export function statusLights({ massiveKey, alphaKey, persistentData, lookalikes = [], market = null, now = Date.now() }) {
  const lights = [];

  // 1) مصدر الأسعار
  if (massiveKey) lights.push({ key: 'prices', level: 'green', label: 'مفتاح Massive موجود — السوق الأمريكي كامل' });
  else if (alphaKey) lights.push({ key: 'prices', level: 'yellow', label: 'أسعار حقيقية لـ«قائمتي» فقط (Alpha Vantage، حد 25 سهم)', fix: 'مسح السوق كامل يحتاج المتغير MASSIVE_API_KEY.' });
  else lights.push({
    key: 'prices', level: 'red', label: 'وضع تجريبي — الأسعار مصطنعة',
    fix: lookalikes.length
      ? `لقيت متغير باسم قريب: ${lookalikes.join('، ')}. لازم يكون الاسم MASSIVE_API_KEY بالضبط (حروف كبيرة، بدون مسافات).`
      : 'الخادم ما شاف أي مفتاح. أضف MASSIVE_API_KEY في Variables بـ Railway — الخدمة تعيد التشغيل لحالها.',
  });

  // 2) المزامنة (فقط مع Massive)
  if (massiveKey && market) {
    const pr = market.progress;
    if (!market.ready && market.error) lights.push({ key: 'sync', level: 'red', label: 'المزامنة متوقفة', fix: market.error });
    else if (!market.ready) lights.push({ key: 'sync', level: 'yellow', label: `المزامنة تتجهز ${market.days}/${HISTORY_DAYS} يوم${pr ? ` (يجلب ${pr.date})` : ''}`, fix: 'أول مرة تاخذ تقريبًا 15 دقيقة. خلّ الصفحة وارجع بعدين.' });
    else if (weekdaysSince(market.lastDay, now) > 3) lights.push({ key: 'sync', level: 'yellow', label: `آخر يوم تداول ${market.lastDay} — قديم`, fix: market.error || 'المزامنة ما جابت أيام جديدة. تأكد إن الخدمة شغالة.' });
    else if (market.error) lights.push({ key: 'sync', level: 'yellow', label: `آخر يوم تداول ${market.lastDay}`, fix: 'آخر محاولة مزامنة فشلت: ' + market.error });
    else lights.push({ key: 'sync', level: 'green', label: `المزامنة شغالة — آخر يوم تداول ${market.lastDay}` });
  }

  // 3) الأخبار والأرباح (اختياري)
  lights.push(alphaKey
    ? { key: 'news', level: 'green', label: 'الأخبار وتقويم الأرباح شغالة (Alpha Vantage)' }
    : { key: 'news', level: 'yellow', label: 'الأخبار وتقويم الأرباح متوقفة', fix: 'اختياري: أضف ALPHA_VANTAGE_KEY.' });

  // 4) التخزين (مع Massive: بدون قرص دائم تنعاد التعبئة بعد كل إعادة تشغيل)
  if (massiveKey) lights.push(persistentData
    ? { key: 'storage', level: 'green', label: 'تخزين الأسعار على قرص دائم' }
    : { key: 'storage', level: 'yellow', label: 'التخزين مؤقت', fix: 'اربط Volume على /data وأضف DATA_DIR=/data، وإلا تنعاد التعبئة (15 دقيقة) بعد كل إعادة تشغيل.' });

  // الشارة: أهم شي — هل الأسعار حقيقية والمزامنة شغالة
  const core = lights.filter(l => l.key === 'prices' || l.key === 'sync');
  const level = worst(core);
  const sync = lights.find(l => l.key === 'sync');
  const badge = !massiveKey && !alphaKey ? 'تجريبي'
    : level === 'red' ? 'المزامنة متوقفة'
    : sync && !market.ready ? `يتجهز ${market.days}/${HISTORY_DAYS}`
    : massiveKey ? `حقيقي · ${market && market.lastDay}` : 'حقيقي · قائمتي';
  return { level, badge, lights };
}
