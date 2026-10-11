import 'package:adeeb/core/app_config.dart';
import 'package:adeeb/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('أرقام مشرقية وفاصلة «٫» في العربية، وغربية في الإنجليزية', () {
    expect(localizeDigits('8.2', 'ar'), '٨٫٢');
    expect(localizeDigits('255', 'ar'), '٢٥٥');
    expect(localizeDigits('8.2', 'en'), '8.2');
  });

  test('الحجم: م.ب بكسر واحد، وك.ب لما دون ١ م.ب', () {
    var s = formatSize(8200000, 'ar');
    expect((s.value, s.unit), ('٨٫٢', SizeUnit.mb));
    s = formatSize(12400000, 'en');
    expect((s.value, s.unit), ('12.4', SizeUnit.mb));
    s = formatSize(1500, 'en');
    expect((s.value, s.unit), ('2', SizeUnit.kb));
    s = formatSize(10, 'ar');
    expect((s.value, s.unit), ('١', SizeUnit.kb));
  });

  test('النسبة المئوية محصورة بين 0 و100', () {
    expect(percentOf(0.456), 45);
    expect(percentOf(1.2), 100);
    expect(percentOf(-1), 0);
  });

  test('رابط المكتبة: https فقط، ويُضاف / في النهاية', () {
    expect(const AppConfig(libraryBaseUrl: '').libraryBaseUri, isNull);
    expect(
      const AppConfig(libraryBaseUrl: 'http://x.test/lib/').libraryBaseUri,
      isNull,
    );
    expect(
      const AppConfig(libraryBaseUrl: 'https://x.test/lib').libraryBaseUri
          .toString(),
      'https://x.test/lib/',
    );
  });
}
