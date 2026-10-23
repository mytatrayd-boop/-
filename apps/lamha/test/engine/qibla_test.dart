import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/qibla.dart';

void main() {
  // ملاحظة: المهمة ذكرت ١٣٤° لتبوك، لكن الحساب (ومكتبة adhan_dart مستقلةً)
  // يعطي ١٥٦٫٣°: مكة جنوب تبوك بنحو ٧° عرض وشرقها بنحو ٣٫٣° طول فقط.
  test('تبوك ≈ ١٥٦° جنوب شرق', () {
    final q = qiblaDegrees(28.3835, 36.5662);
    expect(q, closeTo(156.3, 1));
    expect(directionName(q), 'جنوب شرق');
  });

  test('الرياض ≈ ٢٤٤° جنوب غرب', () {
    final q = qiblaDegrees(24.7136, 46.6753);
    expect(q, closeTo(244, 1));
    expect(directionName(q), 'جنوب غرب');
  });

  test('أسماء الاتجاهات الثمانية', () {
    expect(directionName(0), 'شمال');
    expect(directionName(359), 'شمال');
    expect(directionName(45), 'شمال شرق');
    expect(directionName(90), 'شرق');
    expect(directionName(180), 'جنوب');
    expect(directionName(270), 'غرب');
    expect(directionName(315), 'شمال غرب');
  });
  test('مطابق لمكتبة adhan_dart (تنفيذ مستقل) بفرق أقل من ٠٫١°', () {
    for (final (lat, lon) in [
      (28.3835, 36.5662),
      (24.7136, 46.6753),
      (21.4858, 39.1925),
      (26.4207, 50.0888),
      (51.5074, -0.1278),
    ]) {
      expect(qiblaDegrees(lat, lon),
          closeTo(adhan.Qibla.qibla(adhan.Coordinates(lat, lon)), 0.1));
    }
  });

  test('المسافة إلى مكة: محايل عسير ≈ ٣٩٥ كم، والرياض ≈ ٧٩٣ كم', () {
    expect(distanceToKaabaKm(18.54, 42.05), closeTo(396, 3));
    expect(distanceToKaabaKm(24.6877, 46.7219), closeTo(793, 3));
    expect(distanceToKaabaKm(kaabaLatitude, kaabaLongitude), closeTo(0, 1e-6));
    expect(qiblaDegrees(18.54, 42.05), closeTo(324.4, 0.3));
  });
}
