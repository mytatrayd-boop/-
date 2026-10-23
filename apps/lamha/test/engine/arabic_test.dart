import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/arabic.dart';

void main() {
  test('formatDigits بالاتجاهين (الحالات نفسها في LamhaLogicTest.kt)', () {
    expect(formatDigits(1234567890), '١٢٣٤٥٦٧٨٩٠');
    expect(formatDigits('باقي 3 أيام'), 'باقي ٣ أيام');
    expect(formatDigits('2026-10'), '٢٠٢٦-١٠');
    expect(formatDigits('٢٠٢٦-10 ٤:٥٦ ص', DigitStyle.latin), '2026-10 4:56 ص');
    expect(DigitStyle.byName(null), DigitStyle.arabic);
    expect(DigitStyle.byName('latin'), DigitStyle.latin);
    expect(localizeDigits({'a': ['٣ أيام', 4], 'b': '٢٠٢٦'}, DigitStyle.latin),
        {'a': ['3 أيام', 4], 'b': '2026'});
  });

  test('daysCountText (أعمدة الإيداعات)', () {
    expect(daysCountText(0), 'اليوم');
    expect(daysCountText(1), 'يوم واحد');
    expect(daysCountText(2), 'يومان');
    expect(daysCountText(6), '٦ أيام');
    expect(daysCountText(14), '١٤ يوماً');
  });

  test('remainingDaysText', () {
    expect(remainingDaysText(0), 'اليوم');
    expect(remainingDaysText(1), 'باقي يوم');
    expect(remainingDaysText(2), 'باقي يومان');
    expect(remainingDaysText(3), 'باقي ٣ أيام');
    expect(remainingDaysText(11), 'باقي ١١ يوماً');
  });

  test('remainingMinutesText', () {
    expect(remainingMinutesText(34), 'باقي ٣٤ دقيقة');
    expect(remainingMinutesText(5), 'باقي ٥ دقائق');
  });
}
