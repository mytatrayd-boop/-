import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/astronomy/seasons.dart';
import 'package:lamha/src/engine/astro_season.dart';

void main() {
  const riyadh = Duration(hours: 3);

  test('١٩ أكتوبر ٢٠٢٦: الخريف، والشتاء بعد ٦٣ يوماً (٢١ ديسمبر)', () {
    final s = astroSeasonOn(DateTime(2026, 10, 19), riyadh);
    expect(s.season, AstroSeason.autumn);
    expect(s.name, 'الخريف');
    expect(s.nextName, 'الشتاء');
    expect(s.nextStart, DateTime(2026, 12, 21));
    expect(s.daysRemaining, 63);
    expect(s.remainingText, 'باقي ٦٣ يوماً');
  });

  test('حدود الانقلاب الشتوي ٢٠٢٦ بتوقيت الرياض', () {
    final before = astroSeasonOn(DateTime(2026, 12, 20), riyadh);
    expect(before.season, AstroSeason.autumn);
    expect(before.daysRemaining, 1);
    expect(astroSeasonOn(DateTime(2026, 12, 21), riyadh).season,
        AstroSeason.winter);
  });

  test('الشتاء عبر السنة: ١ يناير ٢٠٢٧ والربيع ٢٠ مارس', () {
    final s = astroSeasonOn(DateTime(2027, 1, 1), riyadh);
    expect(s.season, AstroSeason.winter);
    expect(s.nextStart, DateTime(2027, 3, 20));
    expect(s.daysRemaining, 78);
  });
}
