import 'package:durur/src/updates/update_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// قرار «هل أتحقق الآن» (ARCHITECTURE §16.2، §16.9): 7 أيام بعد النجاح،
/// 24 ساعة بعد الفشل، ولا أثناء الإعداد الأولي.
void main() {
  final t0 = DateTime(2026, 10, 2, 9);

  bool due(
    DateTime now, {
    DateTime? ok,
    DateTime? attempt,
    bool done = true,
    bool auto = true,
  }) => isCheckDue(
    now: now,
    lastCheckOk: ok,
    lastAttempt: attempt,
    onboardingDone: done,
    autoUpdate: auto,
  );

  test('لم يُحاوَل قط ← نعم', () => expect(due(t0), isTrue));

  test('أثناء الإعداد الأولي ← لا (ولو لم يُحاوَل قط)', () {
    expect(due(t0, done: false), isFalse);
    expect(
      due(t0.add(const Duration(days: 30)), ok: t0, attempt: t0, done: false),
      isFalse,
    );
  });

  test('بعد نجاح: لا قبل 7 أيام، ونعم عند 7 أيام', () {
    expect(due(t0.add(const Duration(days: 1)), ok: t0, attempt: t0), isFalse);
    expect(
      due(
        t0.add(const Duration(days: 7) - const Duration(minutes: 1)),
        ok: t0,
        attempt: t0,
      ),
      isFalse,
    );
    expect(due(t0.add(const Duration(days: 7)), ok: t0, attempt: t0), isTrue);
    expect(due(t0.add(const Duration(days: 40)), ok: t0, attempt: t0), isTrue);
  });

  test('بعد فشل: لا قبل 24 ساعة، ونعم عند 24 ساعة', () {
    expect(due(t0.add(const Duration(hours: 23)), attempt: t0), isFalse);
    expect(due(t0.add(const Duration(hours: 24)), attempt: t0), isTrue);
  });

  test('فشل بعد نجاح سابق: يُعتمد الفشل (24 ساعة لا 7 أيام)', () {
    final ok = t0.subtract(const Duration(days: 8));
    expect(due(t0.add(const Duration(hours: 2)), ok: ok, attempt: t0), isFalse);
    expect(due(t0.add(const Duration(hours: 25)), ok: ok, attempt: t0), isTrue);
  });

  test('المفتاح مطفأ ← لا أبداً (ولو لم يُحاوَل قط أو مرّت سنة)', () {
    expect(due(t0, auto: false), isFalse);
    expect(
      due(t0.add(const Duration(days: 365)), ok: t0, attempt: t0, auto: false),
      isFalse,
    );
    expect(
      due(t0.add(const Duration(days: 365)), attempt: t0, auto: false),
      isFalse,
    );
  });

  test('ساعة الجهاز رجعت للخلف ← الوقت المسجّل كأنه الآن (لا تحقق في كل عودة)',
      () {
    final back = t0.subtract(const Duration(days: 2));
    // بعد نجاح: لا، ولا بعد ساعات من الوقت الراجع.
    expect(due(back, ok: t0, attempt: t0), isFalse);
    expect(due(back.add(const Duration(hours: 5)), ok: t0, attempt: t0), isFalse);
    // بعد فشل: لا أيضاً.
    expect(due(back, attempt: t0), isFalse);
    expect(
      due(back, ok: t0.subtract(const Duration(days: 9)), attempt: t0),
      isFalse,
    );
  });

  test('الثابتان كما في D21', () {
    expect(checkIntervalAfterSuccess, const Duration(days: 7));
    expect(checkIntervalAfterFailure, const Duration(hours: 24));
  });
}
