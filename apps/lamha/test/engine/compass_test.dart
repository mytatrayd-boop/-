import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/compass.dart';

void main() {
  test('زاوية السهم = القبلة − اتجاه الجهاز، مطبّعة 0–360', () {
    expect(qiblaArrowAngle(qibla: 243, heading: 0), 243);
    expect(qiblaArrowAngle(qibla: 243, heading: 243), 0);
    expect(qiblaArrowAngle(qibla: 243, heading: 300), 303);
    expect(qiblaArrowAngle(qibla: 10, heading: 350), 20);
    expect(qiblaArrowAngle(qibla: 350, heading: 10), 340);
    expect(qiblaArrowAngle(qibla: 0, heading: 360), 0);
    expect(qiblaArrowAngle(qibla: 324, heading: -36), 0);
  });

  test('التطبيع', () {
    expect(normalizeDegrees(-90), 270);
    expect(normalizeDegrees(720), 0);
    expect(normalizeDegrees(359.5), 359.5);
    for (final d in [-1000.0, -0.1, 0.0, 359.99, 1e6]) {
      final n = normalizeDegrees(d);
      expect(n >= 0 && n < 360, isTrue, reason: '$d → $n');
    }
  });

  test('رسالة المعايرة عند الدقة المنخفضة أو المجهولة', () {
    expect(needsCalibration(15), isFalse);
    expect(needsCalibration(30), isFalse);
    expect(needsCalibration(45), isTrue);
    expect(needsCalibration(null), isTrue);
  });

  test('الانحراف عن أعلى الجهاز من الجهتين', () {
    expect(arrowDeviation(0), 0);
    expect(arrowDeviation(4), 4);
    expect(arrowDeviation(356), 4);
    expect(arrowDeviation(180), 180);
    expect(arrowDeviation(-3), 3);
  });

  test('على القبلة ضمن ٥°، ولا يخرج إلا بعد ٨°', () {
    expect(isAligned(0, wasAligned: false), isTrue);
    expect(isAligned(5, wasAligned: false), isTrue);
    expect(isAligned(355, wasAligned: false), isTrue);
    expect(isAligned(6, wasAligned: false), isFalse);
    expect(isAligned(6, wasAligned: true), isTrue);
    expect(isAligned(352, wasAligned: true), isTrue);
    expect(isAligned(9, wasAligned: true), isFalse);
    expect(isAligned(180, wasAligned: true), isFalse);
  });
}
