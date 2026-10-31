import 'package:bunn_lens/features/share/user_name.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('normalizeUserName', () {
    test('يقلّم ويوحّد المسافات', () {
      expect(normalizeUserName('  أحمد   علي \n'), 'أحمد علي');
    });
    test('الفارغ والمسافات وnull = فارغ', () {
      expect(normalizeUserName(null), '');
      expect(normalizeUserName('   '), '');
    });
    test('يقصّ الاسم الطويل إلى الحد الأقصى', () {
      final out = normalizeUserName('ع' * 100);
      expect(out.runes.length, userNameMaxLength);
    });
  });

  group('ensureUserName (منع المشاركة بلا اسم)', () {
    test('اسم موجود: لا يسأل ولا يحفظ', () async {
      var asked = 0;
      final saved = <String>[];
      final r = await ensureUserName(
        current: 'سارة',
        ask: () async {
          asked++;
          return 'x';
        },
        save: (n) async => saved.add(n),
      );
      expect(r, 'سارة');
      expect(asked, 0);
      expect(saved, isEmpty);
    });

    test('اسم فارغ: يسأل ثم يحفظ الاسم المنظَّف', () async {
      final saved = <String>[];
      final r = await ensureUserName(current: '', ask: () async => '  خالد ', save: (n) async => saved.add(n));
      expect(r, 'خالد');
      expect(saved, ['خالد']);
    });

    test('مسافات فقط تُعدّ فارغة', () async {
      var asked = 0;
      final r = await ensureUserName(
          current: '   ',
          ask: () async {
            asked++;
            return 'منى';
          },
          save: (_) async {});
      expect(asked, 1);
      expect(r, 'منى');
    });

    test('إلغاء الحوار أو رد فارغ: يعيد null ولا يحفظ (لا مشاركة)', () async {
      final saved = <String>[];
      expect(await ensureUserName(current: '', ask: () async => null, save: (n) async => saved.add(n)), isNull);
      expect(await ensureUserName(current: '', ask: () async => '  ', save: (n) async => saved.add(n)), isNull);
      expect(saved, isEmpty);
    });
  });

  group('userNameProvider (shared_preferences)', () {
    test('يبدأ فارغاً ثم يحفظ ويبقى بعد إعادة التحميل', () async {
      SharedPreferences.setMockInitialValues({});
      final c1 = ProviderContainer();
      addTearDown(c1.dispose);
      expect(await c1.read(userNameProvider.future), '');
      await c1.read(userNameProvider.notifier).setName('  نورة  ');
      expect(c1.read(userNameProvider).value, 'نورة');

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      expect(await c2.read(userNameProvider.future), 'نورة');
    });

    test('التعديل يستبدل الاسم السابق', () async {
      SharedPreferences.setMockInitialValues({userNamePrefsKey: 'قديم'});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(await c.read(userNameProvider.future), 'قديم');
      await c.read(userNameProvider.notifier).setName('جديد');
      expect((await SharedPreferences.getInstance()).getString(userNamePrefsKey), 'جديد');
    });
  });
}
