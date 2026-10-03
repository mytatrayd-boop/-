// الاحتفاظ الليلي مقابل النهاري على SPY/QQQ: «ليلي» = شراء بالإغلاق وبيع بافتتاح الغد، «نهاري» = شراء بالافتتاح وبيع بالإغلاق.
// فلتر اختياري: SPY فوق متوسط 200 (بيانات حتى الأمس). التكاليف تُحسب في كل جانب كل يوم — اختبار قاسٍ عمدًا.
import { regimeFn } from './common.mjs';
export default {
  family: 'overnight', name: 'الاحتفاظ الليلي مقابل النهاري', universe: 'etf',
  grid: { asset: ['SPY', 'QQQ'], mode: ['overnight', 'intraday'], regime: ['none', 'sma200'] },
  make(p) {
    const night = p.mode === 'overnight';
    const cfg = {
      universe: [p.asset], maxPositions: 1, entryAt: night ? 'close' : 'open', exitAt: night ? 'open' : 'close', hold: night ? 1 : 0,
      init(P) { cfg.regime = regimeFn(P, p.regime); },
      score: () => 1,
    };
    return cfg;
  },
};
