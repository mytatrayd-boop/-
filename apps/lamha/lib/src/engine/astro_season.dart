import '../astronomy/seasons.dart';
import 'arabic.dart';
import 'traditional_seasons.dart';

/// الفصل الفلكي الحالي والأيام المتبقية للفصل التالي (حساب Meeus المنسوخ من
/// دليل المواسم، `lib/src/astronomy/seasons.dart`).

const astroSeasonNames = {
  AstroSeason.spring: 'الربيع',
  AstroSeason.summer: 'الصيف',
  AstroSeason.autumn: 'الخريف',
  AstroSeason.winter: 'الشتاء',
};

class CurrentAstroSeason {
  const CurrentAstroSeason({
    required this.season,
    required this.nextStart,
    required this.daysRemaining,
  });

  final AstroSeason season;

  /// اليوم المحلي لبداية الفصل التالي.
  final DateTime nextStart;
  final int daysRemaining;

  AstroSeason get nextSeason => season.next;
  String get name => astroSeasonNames[season]!;
  String get nextName => astroSeasonNames[nextSeason]!;
  String get remainingText => remainingDaysText(daysRemaining);

  Map<String, Object> toJson() => {
        'id': season.name,
        'name': name,
        'next': {'id': nextSeason.name, 'name': nextName},
        'nextStart': isoDate(nextStart),
        'daysRemaining': daysRemaining,
        'remainingText': remainingText,
        'afterText': afterDaysText(daysRemaining),
      };
}

/// الفصل الذي يقع فيه اليوم المحلي [day] بإزاحة [utcOffset] للمنطقة الزمنية.
CurrentAstroSeason astroSeasonOn(DateTime day, Duration utcOffset) {
  final d = DateTime(day.year, day.month, day.day);
  final period =
      AstroYear.compute(d.year, utcOffset: utcOffset).seasonAt(d);
  return CurrentAstroSeason(
    season: period.value,
    nextStart: period.end.day,
    daysRemaining: daysBetween(d, period.end.day),
  );
}

/// الفصل المناخي لمربع «الفصل» (قرار المالك ٢٩/١٠/٢٠٢٦): يبدأ كل فصل مع موسمه في دليل الطوالع
/// (`opens` في seasons.json)، فالشتاء يدخل مع المربعانية ولا تسبقه أبداً. نفس مفاتيح الفصل الفلكي.
CurrentAstroSeason climateSeasonOn(TradSeasonsTable table, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  final starts = [
    for (final s in table.seasons)
      if (s.opens != null) (season: AstroSeason.values.byName(s.opens!), month: s.startMonth, day: s.startDay),
  ];
  if (starts.length != 4) throw const FormatException('seasons.json: يلزم opens لأربعة مواسم.');
  DateTime at(int year, ({AstroSeason season, int month, int day}) x) => DateTime(year, x.month, x.day);
  // آخر بداية ≤ d (هذه السنة أو السابقة)، والتالية بعدها.
  final all = [
    for (final y in [d.year - 1, d.year, d.year + 1])
      for (final x in starts) (season: x.season, start: at(y, x)),
  ]..sort((a, b) => a.start.compareTo(b.start));
  final i = all.lastIndexWhere((x) => !x.start.isAfter(d));
  final next = all[i + 1];
  return CurrentAstroSeason(
    season: all[i].season,
    nextStart: next.start,
    daysRemaining: daysBetween(d, next.start),
  );
}
