import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('أصول اللوقو مسجلة وقابلة للتحميل', () async {
    for (final name in ['logo', 'logo-light', 'logo-mark']) {
      final data = await rootBundle.load('assets/$name.png');
      expect(data.lengthInBytes, greaterThan(0), reason: name);
    }
  });
}
