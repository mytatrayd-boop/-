// أثر نهاية/بداية الشهر على SPY أو QQQ: شراء بإغلاق آخر يوم تداول في الشهر (أو قبله بيومين)
// والبيع بإغلاق اليوم الثاني/الرابع من الشهر الجديد. نقد في باقي الأيام. القرار تقويمي بحت (يُعرف قبل الإغلاق).
import { daysToMonthEnd } from './common.mjs';
export default {
  family: 'calendar-tom', name: 'أثر بداية الشهر (صندوق مؤشر)', universe: 'etf',
  grid: { asset: ['SPY', 'QQQ'], before: [0, 2], after: [2, 4] },
  make(p) {
    let P;
    return {
      universe: [p.asset], maxPositions: 1, entryAt: 'close', exitAt: 'close', hold: p.before + p.after,
      init(x) { P = x; },
      score: (dDecision, s, dFill) => (daysToMonthEnd(P, dFill) === p.before ? 1 : null),
    };
  },
};
