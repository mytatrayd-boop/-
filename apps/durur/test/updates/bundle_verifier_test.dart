import 'dart:convert';
import 'dart:typed_data';

import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/updates/bundle_verifier.dart';
import 'package:durur/src/updates/data_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import 'update_test_kit.dart';

/// قبول الحزمة ورفضها (ARCHITECTURE §16.3، §16.6، §16.7، §16.9).
void main() {
  late TestSigner signer;
  late Tables embedded;
  late BundleVerifier verifier;

  setUpAll(() async {
    signer = await TestSigner.generate();
    embedded = await loadAssetTables();
    verifier = BundleVerifier(signer.trustedKeys);
  });

  Future<VerifiedBundle> verify(
    Release r, {
    int appBuild = 1,
    int minSeq = 0,
    BundleVerifier? using,
  }) => (using ?? verifier).verify(
    r.manifest,
    r.bundle,
    embedded: embedded,
    appBuild: appBuild,
    minSeqExclusive: minSeq,
  );

  Matcher rejectedWith(RejectReason reason) => throwsA(
    isA<UpdateRejected>().having((e) => e.reason, 'reason', reason),
  );

  /// يوقّع [bundle] ببيان صحيح ما لم تُمرَّر قيم مخالفة.
  Future<Release> signed(Uint8List bundle, int seq) async =>
      (manifest: await signer.manifest(bundle, seq: seq), bundle: bundle);

  group('القبول', () {
    test('حزمة معتمدة صحيحة التوقيع تُقبل وتحمل رقمها', () async {
      final result = await verify(await buildRelease(signer, 3));
      expect(result.manifest.dataSeq, 3);
      expect(result.tables.meta.dataSeq, 3);
      expect(result.tables.meta.dataVersion, 'test-3');
      expect(result.tables.hasUnapproved, isFalse);
      expect(result.tables.cities.length, embedded.cities.length);
      expect(result.tables.hijri, isNotNull);
    });

    test('إضافة مدينة مسموحة', () async {
      final r = await buildRelease(
        signer,
        1,
        mutate: (f) {
          final cities = f['cities.json']! as List;
          final copy = jsonDecode(jsonEncode(cities.first)) as Map;
          copy['id'] = 'new_city';
          cities.add(copy);
        },
      );
      final result = await verify(r);
      expect(result.tables.city('new_city'), isNotNull);
    });

    test('تصحيح بداية شهر هجري بيوم واحد مقبول', () async {
      final r = await buildRelease(signer, 1, mutate: shiftHijriMonth(1));
      final result = await verify(r);
      expect(result.tables.hijri!.monthStarts, isNot(embedded.hijri!.monthStarts));
    });
  });

  group('التوقيع', () {
    test('مفتاح آخر بالمعرّف نفسه ← رفض', () async {
      final other = await TestSigner.generate();
      final r = await buildRelease(other, 1);
      await expectLater(verify(r), rejectedWith(RejectReason.badSignature));
    });

    test('بايت معدّل في المحتوى ← رفض', () async {
      final r = await buildRelease(signer, 1);
      final env = jsonDecode(utf8.decode(r.manifest)) as Map<String, Object?>;
      final payload = base64.decode(env['payload']! as String);
      // تغيير رقم الحزمة داخل المحتوى الموقّع.
      final text = utf8.decode(payload).replaceFirst('"dataSeq":1', '"dataSeq":9');
      env['payload'] = base64.encode(utf8.encode(text));
      final tampered = Uint8List.fromList(utf8.encode(jsonEncode(env)));
      await expectLater(
        verify((manifest: tampered, bundle: r.bundle)),
        rejectedWith(RejectReason.badSignature),
      );
    });

    test('توقيع ناقص ← رفض', () async {
      final r = await buildRelease(signer, 1);
      final env = jsonDecode(utf8.decode(r.manifest)) as Map<String, Object?>;
      final sig = base64.decode(env['signature']! as String);
      env['signature'] = base64.encode(sig.sublist(0, 32));
      final cut = Uint8List.fromList(utf8.encode(jsonEncode(env)));
      await expectLater(
        verify((manifest: cut, bundle: r.bundle)),
        rejectedWith(RejectReason.badSignature),
      );
    });

    test('keyId مجهول ← رفض', () async {
      final r = await buildRelease(signer, 1);
      final env = jsonDecode(utf8.decode(r.manifest)) as Map<String, Object?>;
      env['keyId'] = 'k9';
      final m = Uint8List.fromList(utf8.encode(jsonEncode(env)));
      await expectLater(
        verify((manifest: m, bundle: r.bundle)),
        rejectedWith(RejectReason.unknownKey),
      );
    });

    test('بلا مفاتيح موثوقة (ثابت الإنتاج الفارغ) ← رفض كل حزمة', () async {
      await expectLater(
        verify(await buildRelease(signer, 1), using: const BundleVerifier({})),
        rejectedWith(RejectReason.unknownKey),
      );
    });

    test('بيان تالف ← رفض', () async {
      final r = await buildRelease(signer, 1);
      await expectLater(
        verify((manifest: Uint8List.fromList(utf8.encode('{')), bundle: r.bundle)),
        rejectedWith(RejectReason.badManifest),
      );
    });
  });

  group('البيان', () {
    late Uint8List bundle;
    setUpAll(() async => bundle = (await buildRelease(signer, 5)).bundle);

    Future<void> expectManifest(Uint8List m, RejectReason reason) =>
        expectLater(
          verify((manifest: m, bundle: bundle)),
          rejectedWith(reason),
        );

    test('تطبيق آخر ← رفض', () async {
      await expectManifest(
        await signer.manifest(bundle, seq: 5, app: 'com.other.app'),
        RejectReason.wrongApp,
      );
    });

    test('مخطط آخر ← رفض', () async {
      await expectManifest(
        await signer.manifest(bundle, seq: 5, schemaVersion: 2),
        RejectReason.unsupportedSchema,
      );
    });

    test('minAppBuild أكبر من رقم البناء ← رفض', () async {
      await expectManifest(
        await signer.manifest(bundle, seq: 5, minAppBuild: 2),
        RejectReason.appTooOld,
      );
    });

    test('مسار حزمة غير bundle-<seq>.json ← رفض', () async {
      await expectManifest(
        await signer.manifest(bundle, seq: 5, path: '../bundle-5.json'),
        RejectReason.badManifest,
      );
    });
  });

  group('الرقم (dataSeq)', () {
    test('أقل من المقبول سابقاً أو مساوٍ له ← رفض', () async {
      final r = await buildRelease(signer, 4);
      await expectLater(verify(r, minSeq: 4), rejectedWith(RejectReason.notNewer));
      await expectLater(verify(r, minSeq: 7), rejectedWith(RejectReason.notNewer));
      expect((await verify(r, minSeq: 3)).manifest.dataSeq, 4);
    });

    test('0 (مساوٍ للمضمّن) ← رفض', () async {
      final r = await buildRelease(signer, 0);
      await expectLater(verify(r), rejectedWith(RejectReason.notNewer));
    });

    test('meta.json في الحزمة برقم آخر ← رفض', () async {
      final files = approve(await assetFiles(), 2);
      final bundle = Uint8List.fromList(encodeBundle(files));
      final m = await signer.manifest(bundle, seq: 3, dataVersion: 'test-2');
      await expectLater(
        verify((manifest: m, bundle: bundle)),
        rejectedWith(RejectReason.metaMismatch),
      );
    });
  });

  group('السلامة', () {
    test('بصمة خاطئة (الحجم نفسه) ← رفض', () async {
      final r = await buildRelease(signer, 1);
      final changed = Uint8List.fromList(r.bundle);
      final i = utf8.decode(changed).indexOf('test-1');
      changed[i] = 'T'.codeUnitAt(0);
      await expectLater(
        verify((manifest: r.manifest, bundle: changed)),
        rejectedWith(RejectReason.hashMismatch),
      );
    });

    test('بصمة في البيان لا تطابق ← رفض', () async {
      final r = await buildRelease(signer, 1);
      final m = await signer.manifest(r.bundle, seq: 1, sha256: '0' * 64);
      await expectLater(
        verify((manifest: m, bundle: r.bundle)),
        rejectedWith(RejectReason.hashMismatch),
      );
    });

    test('حجم مخالف ← رفض', () async {
      final r = await buildRelease(signer, 1);
      final longer = Uint8List.fromList([...r.bundle, 32]);
      await expectLater(
        verify((manifest: r.manifest, bundle: longer)),
        rejectedWith(RejectReason.sizeMismatch),
      );
    });

    test('JSON تالف موقّع ← رفض', () async {
      final r = await signed(Uint8List.fromList(utf8.encode('{"format":1,')), 1);
      await expectLater(verify(r), rejectedWith(RejectReason.badBundle));
    });

    test('ملف ناقص في الحزمة ← رفض', () async {
      final files = approve(await assetFiles(), 1)..remove('items.json');
      final r = await signed(Uint8List.fromList(encodeBundle(files)), 1);
      await expectLater(verify(r), rejectedWith(RejectReason.badBundle));
    });
  });

  group('المدقق (TableValidator بوضع الإطلاق)', () {
    test('سجل مسودة ← رفض', () async {
      final r = await buildRelease(
        signer,
        1,
        mutate: (f) {
          final cities = f['cities.json']! as List;
          (cities.first as Map)['approval'] = {
            'status': 'draft',
            'reviewer': null,
            'date': null,
          };
        },
      );
      await expectLater(verify(r), rejectedWith(RejectReason.invalidTables));
    });

    test('بيانات المستودع الحالية (تجريبية) ← رفض', () async {
      final files = await assetFiles();
      (files['meta.json']! as Map)['dataSeq'] = 1;
      final bundle = Uint8List.fromList(encodeBundle(files));
      final m = await signer.manifest(bundle, seq: 1, dataVersion: 'sample-1');
      await expectLater(
        verify((manifest: m, bundle: bundle)),
        rejectedWith(RejectReason.invalidTables),
      );
    });

    test('طبقة متصلة ببدايات مكررة ← رفض', () async {
      final r = await buildRelease(
        signer,
        1,
        mutate: (f) {
          final stars = (f[regionFile('najd')]! as Map)['stars'] as List;
          (stars[1] as Map)['start'] = (stars[0] as Map)['start'];
        },
      );
      await expectLater(verify(r), rejectedWith(RejectReason.invalidTables));
    });

    test('شهر هجري 31 يوماً ← رفض', () async {
      final r = await buildRelease(
        signer,
        1,
        mutate: (f) {
          final starts = hijriStarts(f);
          // تأخير بداية شهر طوله 30 بيومين يجعل السابق 31 أو أكثر.
          starts[13] = isoPlusDays(starts[13] as String, 2);
        },
      );
      await expectLater(verify(r), rejectedWith(RejectReason.invalidTables));
    });
  });

  group('الهجري مقابل المضمّن', () {
    test('إزاحة كل الجدول بيومين ← رفض (الأطوال سليمة)', () async {
      final r = await buildRelease(
        signer,
        1,
        mutate: (f) {
          final starts = hijriStarts(f);
          for (var i = 0; i < starts.length; i++) {
            starts[i] = isoPlusDays(starts[i] as String, 2);
          }
          // التغطية تبقى: الجدول يبدأ 2024 وينتهي بعد 2040.
        },
      );
      await expectLater(verify(r), rejectedWith(RejectReason.hijriShift));
    });
  });

  group('التوافق (لا حذف)', () {
    test('حذف مدينة ← رفض', () async {
      final r = await buildRelease(
        signer,
        1,
        mutate: (f) => (f['cities.json']! as List).removeWhere(
          (c) => (c as Map)['id'] == 'riyadh',
        ),
      );
      await expectLater(
        verify(r),
        throwsA(
          isA<UpdateRejected>()
              .having((e) => e.reason, 'reason', RejectReason.removedIds)
              .having((e) => e.detail, 'detail', contains('riyadh')),
        ),
      );
    });

    test('removedIds يكشف المنطقة والعنصر المحذوفين', () async {
      final r = await verify(await buildRelease(signer, 1));
      final fewer = Tables(
        meta: r.tables.meta,
        regions: r.tables.regions.skip(1).toList(),
        itemList: r.tables.itemList.skip(1).toList(),
        regionTables: r.tables.regionTables,
        cities: r.tables.cities,
      );
      expect(removedIds(embedded, fewer), [
        'regions.json:${embedded.regions.first.id}',
        'items.json:${embedded.itemList.first.id}',
      ]);
      expect(removedIds(embedded, r.tables), isEmpty);
    });
  });
}

/// يؤخر بداية شهر (ليس محرم) بيوم حيث السابق 29 والحالي 30، فتبقى الأطوال
/// 29/30 والسنة كما هي: تصحيح مقبول بيوم واحد.
void Function(Map<String, Object?>) shiftHijriMonth(int days) => (files) {
  final starts = hijriStarts(files);
  DateTime at(int i) => DateTime.parse('${starts[i]}T00:00:00Z');
  for (var i = 1; i + 1 < starts.length; i++) {
    if (i % 12 == 0) continue; // بداية سنة: تغيّر طول السنتين.
    final prev = at(i).difference(at(i - 1)).inDays;
    final cur = at(i + 1).difference(at(i)).inDays;
    if (prev == 29 && cur == 30) {
      starts[i] = isoPlusDays(starts[i]! as String, days);
      return;
    }
  }
  fail('لا شهر مناسب للإزاحة');
};
