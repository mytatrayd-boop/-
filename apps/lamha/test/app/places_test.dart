import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/places.dart';
import 'package:lamha/src/app/services.dart';

void main() {
  test('اسم المكان: locality ثم subAdministrativeArea ثم administrativeArea', () {
    expect(
        placemarkName(
            locality: 'أبها',
            subAdministrativeArea: 'محافظة أبها',
            administrativeArea: 'منطقة عسير'),
        'أبها');
    expect(
        placemarkName(
            locality: ' ',
            subAdministrativeArea: 'محافظة النماص',
            administrativeArea: 'منطقة عسير'),
        'محافظة النماص');
    expect(placemarkName(locality: '', administrativeArea: 'منطقة عسير'),
        'منطقة عسير');
    expect(placemarkName(), isNull);
  });

  test('البحث مقيد بالسعودية', () {
    expect(searchAddress(' النماص '), 'النماص، السعودية');
  });

  test('رابط القبلة من الودجت', () {
    expect(isQiblaLaunch(Uri.parse('lamha://qibla')), isTrue);
    expect(isQiblaLaunch(qiblaLaunchUri), isTrue);
    expect(isQiblaLaunch(Uri()), isFalse);
    expect(isQiblaLaunch(Uri.parse('lamha://settings')), isFalse);
    expect(isQiblaLaunch(null), isFalse);
  });

  test('حدود السعودية: أبها وتبوك والدمام داخلها، والقاهرة وبغداد خارجها (الحدود تقريبية مستطيلة)', () {
    expect(inSaudiBounds(18.2164, 42.5053), isTrue);
    expect(inSaudiBounds(28.3835, 36.5662), isTrue);
    expect(inSaudiBounds(26.4207, 50.0888), isTrue);
    expect(inSaudiBounds(30.0444, 31.2357), isFalse);
    expect(inSaudiBounds(33.3152, 44.3661), isFalse);
  });
}
