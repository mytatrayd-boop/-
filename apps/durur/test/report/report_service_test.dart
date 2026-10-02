import 'package:durur/src/report/report_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// الميزة 9: ReportService (نموذج ← نسخ)، وقراءة الإعدادات، وبناء الرابط.
void main() {
  const message = ReportMessage(
    lines: ['العنصر: الوسم', 'المنطقة: نجد', 'نسخة التطبيق: ١.٠.٠+١'],
    values: {
      ReportField.item: 'الوسم',
      ReportField.region: 'نجد',
      ReportField.date: '2026-10-02',
      ReportField.appVersion: '1.0.0+1',
      ReportField.dataVersion: 'sample-1 (0)',
    },
  );
  const form = 'https://docs.example.com/forms/d/e/ABC/viewform';

  /// خدمة بفاتح وناسخ مسجّلَين بالترتيب في [log].
  ReportService service(
    ReportConfig config,
    List<String> log, {
    bool opens = true,
    bool throws = false,
  }) => ReportService(
    config: config,
    openUrl: (uri) async {
      log.add('open $uri');
      if (throws) throw StateError('no browser');
      return opens;
    },
    copyText: (text) async => log.add('copy $text'),
  );

  group('ترتيب البدائل: نموذج ← نسخ', () {
    test('بلا إعدادات (القيم فارغة): نسخ فقط، ولا محاولة فتح ولا نسخ تلقائي', () async {
      final log = <String>[];
      final config = const ReportConfig();
      expect(config.hasForm, isFalse);
      expect(config.prefills, isFalse);
      expect(
        await service(config, log).report(message),
        ReportOutcome.copy,
      );
      expect(log, isEmpty);
    });

    test('قيم فيها مسافات فقط تُعامل كفارغة', () async {
      final log = <String>[];
      final config = const ReportConfig(formUrl: '  ', formFields: ' ');
      expect(config.hasForm, isFalse);
      expect(await service(config, log).report(message), ReportOutcome.copy);
      expect(log, isEmpty);
    });

    test('نموذج بلا حقول: يُنسخ النص أولاً ثم يُفتح النموذج كما هو', () async {
      final log = <String>[];
      final outcome = await service(
        const ReportConfig(formUrl: form),
        log,
      ).report(message);
      expect(outcome, ReportOutcome.formWithCopiedText);
      expect(log, ['copy ${message.text}', 'open $form']);
    });

    test('نموذج بحقول: يُفتح معبأً مسبقاً بلا نسخ', () async {
      final log = <String>[];
      final outcome = await service(
        const ReportConfig(
          formUrl: form,
          formFields: 'item=entry.11,region=entry.22,date=entry.33',
        ),
        log,
      ).report(message);
      expect(outcome, ReportOutcome.formPrefilled);
      expect(log, hasLength(1));
      final opened = Uri.parse(log.single.substring('open '.length));
      expect(opened.host, 'docs.example.com');
      expect(opened.queryParameters, {
        'entry.11': 'الوسم',
        'entry.22': 'نجد',
        'entry.33': '2026-10-02',
      });
    });

    test('فشل الفتح أو رميه ← نافذة النسخ', () async {
      for (final throws in [false, true]) {
        for (final fields in ['', 'item=entry.1']) {
          final log = <String>[];
          final outcome = await service(
            ReportConfig(formUrl: form, formFields: fields),
            log,
            opens: false,
            throws: throws,
          ).report(message);
          expect(outcome, ReportOutcome.copy, reason: '$throws $fields');
          expect(log.where((l) => l.startsWith('open ')), hasLength(1));
        }
      }
    });

    test('فشل النسخ قبل فتح النموذج ← copyFailed (لا «تعذّر فتح النموذج») '
        'بلا فتح', () async {
      final log = <String>[];
      final s = ReportService(
        config: const ReportConfig(formUrl: form),
        openUrl: (uri) async {
          log.add('open');
          return true;
        },
        copyText: (_) async => throw StateError('clipboard'),
      );
      expect(await s.report(message), ReportOutcome.copyFailed);
      expect(log, isEmpty);
    });
  });

  group('رفض المخططات غير المسموحة', () {
    test('رابط نموذج ليس https بنطاق لا يُعدّ نموذجاً ولا يُفتح', () async {
      for (final url in [
        'http://docs.example.com/form',
        'mailto:someone@example.com',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'intent://x#Intent;end',
        'https:///nohost',
        '/relative/form',
        'not a url',
        'ftp://example.com/form',
      ]) {
        final log = <String>[];
        final config = ReportConfig(formUrl: url, formFields: 'item=entry.1');
        expect(config.hasForm, isFalse, reason: url);
        expect(config.prefills, isFalse, reason: url);
        expect(
          await service(config, log).report(message),
          ReportOutcome.copy,
          reason: url,
        );
        expect(log, isEmpty, reason: url);
      }
    });

    test('isOpenableUrl: https بنطاق فقط', () {
      expect(isOpenableUrl(Uri.parse(form)), isTrue);
      expect(isOpenableUrl(Uri.parse('HTTPS://example.com')), isTrue);
      expect(isOpenableUrl(Uri.parse('http://example.com')), isFalse);
      expect(isOpenableUrl(Uri.parse('mailto:a@b.c')), isFalse);
    });
  });

  group('REPORT_FORM_FIELDS', () {
    test('يقرأ الأزواج الصالحة ويهمل غيرها', () {
      expect(
        parseFormFields(
          ' item = entry.1 ,region=entry.22,date=entry.333,'
          'appVersion=entry.4,dataVersion=entry.5,details=entry.6',
        ),
        {
          ReportField.item: 'entry.1',
          ReportField.region: 'entry.22',
          ReportField.date: 'entry.333',
          ReportField.appVersion: 'entry.4',
          ReportField.dataVersion: 'entry.5',
          ReportField.details: 'entry.6',
        },
      );
      for (final bad in [
        '',
        'item',
        '=entry.1',
        'city=entry.1', // ليس حقلاً مسموحاً
        'lat=entry.2',
        'item=entry.',
        'item=entry.1&x=y',
        'item=entry.1?x',
        'item=foo',
        'item=entry.abc',
      ]) {
        expect(parseFormFields(bad), isEmpty, reason: bad);
      }
    });

    test('الرابط يحفظ معاملاته الأصلية ويرمّز العربية والأسطر', () {
      final uri = buildFormUri(
        Uri.parse('$form?usp=pp_url'),
        {ReportField.details: 'entry.9', ReportField.item: 'entry.1'},
        message,
      );
      expect(uri.scheme, 'https');
      expect(uri.toString(), isNot(contains(' ')));
      expect(uri.toString(), isNot(contains('\n')));
      expect(uri.queryParameters['usp'], 'pp_url');
      expect(uri.queryParameters['entry.1'], 'الوسم');
      expect(uri.queryParameters['entry.9'], message.text);
    });

    test('بلا حقول يبقى الرابط كما هو', () {
      final base = Uri.parse(form);
      expect(buildFormUri(base, const {}, message), base);
    });
  });
}
