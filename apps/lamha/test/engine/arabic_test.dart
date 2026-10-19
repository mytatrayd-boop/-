import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/arabic.dart';

void main() {
  test('arabicDigits', () {
    expect(arabicDigits(1234567890), '١٢٣٤٥٦٧٨٩٠');
    expect(arabicDigits('باقي 3 أيام'), 'باقي ٣ أيام');
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
