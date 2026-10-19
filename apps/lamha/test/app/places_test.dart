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
}
