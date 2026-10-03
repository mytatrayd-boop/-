// انكماش التذبذب ثم الاختراق: يوم NR7 أو يوم داخلي (اختياريًا في اتجاه صاعد: إغلاق > متوسط 50 > متوسط 200)
// → أمر إيقاف شراء فوق أعلى يوم الإعداد غدًا. الوقف = أدنى يوم الإعداد. الخروج بعد 3/5/10 أيام.
export default {
  family: 'vcp-breakout', name: 'انكماش ثم اختراق (NR7 / يوم داخلي)', universe: 'large',
  grid: { pattern: ['nr7', 'inside'], hold: [3, 5, 10], trend: ['up', 'none'] },
  make(p) {
    let c, h, l, pat, m50, m200, r126;
    return {
      universe: 'large', maxPositions: 5, entryAt: 'stop', exitAt: 'open', hold: p.hold,
      init(P) { c = P.c; h = P.h; l = P.l; pat = P.series(p.pattern); m50 = P.series('sma:50'); m200 = P.series('sma:200'); r126 = P.series('ret:126'); },
      score(d, s) {
        if (pat[s][d] !== 1) return null;
        if (p.trend === 'up' && !(c[s][d] > m50[s][d] && m50[s][d] > m200[s][d])) return null;
        const sc = r126[s][d];
        return Number.isFinite(sc) ? { score: sc, trigger: h[s][d] * 1.0001, stop: l[s][d] } : null;
      },
    };
  },
  rules: p => [
    'الكون: أعلى 500 سهم متوافق بمتوسط قيمة التداول 60 يومًا، سعر ≥ 5$.',
    `الإعداد: يوم ${p.pattern === 'nr7' ? 'NR7 (أضيق مدى في 7 أيام)' : 'داخلي (داخل مدى الأمس)'}${p.trend === 'up' ? ' والإغلاق > متوسط 50 > متوسط 200' : ''}.`,
    'الدخول: أمر إيقاف شراء فوق أعلى يوم الإعداد صالح ليوم واحد.',
    `الوقف: أدنى يوم الإعداد. الخروج: بافتتاح اليوم ${p.hold} بعد الدخول.`,
    'الحجم: 20% لكل سهم، حد أقصى 5 مراكز.',
  ],
};
