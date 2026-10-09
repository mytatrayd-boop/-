import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mawid/core/remote_holidays.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const good = '[{"kind":"summer","start":"2027-06-25","end":"2027-08-21"}]';

  test('الجلب الصالح يُحفظ ويُقرأ، والفاسد أو الفاشل لا يمس النسخة الجيدة', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    expect(cachedHolidays(p), isEmpty);

    final ok = await refreshHolidays(p, MockClient((_) async => http.Response(good, 200)));
    expect(ok!.length, 1);
    expect(cachedHolidays(p).length, 1);

    expect(await refreshHolidays(p, MockClient((_) async => http.Response('not json', 200))), isNull);
    expect(await refreshHolidays(p, MockClient((_) async => http.Response('x', 404))), isNull);
    expect(await refreshHolidays(p, MockClient((_) async => throw Exception('offline'))), isNull);
    expect(cachedHolidays(p).length, 1); // النسخة الجيدة باقية
  });
}
