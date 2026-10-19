import '../astronomy/seasons.dart';
import 'arabic.dart';

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
