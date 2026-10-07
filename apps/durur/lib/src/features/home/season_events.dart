import '../../domain/day_info.dart';
import '../../domain/item.dart';

/// أحداث العدّاد وبطاقة «القادم» (DESIGN R2.8). Dart صافٍ.
///
/// الحدث بداية فترة بعد التاريخ المعروض: موسم جو، أو طالع، أو موسم كبير،
/// أو دَرّ؛ وطلوع سهيل/الثريا المحسوب لمدينة المستخدم بدل بداية سجلهما في
/// الجدول (الميزة 5).

enum SeasonEventKind {
  // الترتيب أولوية التساوي في العدّاد: موسم الجو ← الطالع ← الموسم الكبير.
  weatherSeason,
  star,
  majorSeason,
  dar,
}

class SeasonEvent {
  const SeasonEvent({
    required this.kind,
    required this.date,
    required this.days,
    this.itemId,
    this.dar,
    this.computed = false,
  });

  final SeasonEventKind kind;

  /// يوم البداية (محلي، منتصف الليل).
  final DateTime date;

  /// الأيام من التاريخ المعروض إلى [date] (0 = اليوم نفسه).
  final int days;

  /// عنصر الموسم أو النجم أو موسم الجو.
  final String? itemId;

  /// الدَّرّ الذي يبدأ (لـ [SeasonEventKind.dar]).
  final DarPeriod? dar;

  /// طلوع محسوب فلكياً لمدينة المستخدم (سهيل والثريا).
  final bool computed;

  bool sameAs(SeasonEvent other) =>
      kind == other.kind && itemId == other.itemId && date == other.date;
}

/// كل بدايات الفترات من [from] (شاملاً) حتى [horizon] يوماً بعده، مرتبة
/// بالتاريخ ثم بأولوية النوع. [resolve] نتيجة المحرك ليوم (null خارج المدى).
/// [rising] تاريخ الطلوع المحسوب لعنصر في سنة (UTC منتصف الليل)، أو null.
List<SeasonEvent> seasonEvents({
  required DateTime from,
  required DayInfo? Function(DateTime day) resolve,
  required Map<String, Item> items,
  DateTime? Function(String itemId, int year)? rising,
  int horizon = 370,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final out = <SeasonEvent>[];
  bool startsOn(ActivePeriod p, DateTime day) =>
      p.start == DateTime.utc(day.year, day.month, day.day);
  bool heliacal(String id) => items[id]?.dateMethod == DateMethod.heliacal;

  for (var i = 0; i <= horizon; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    final info = resolve(day);
    if (info == null) continue;
    final ws = info.weatherSeason;
    if (ws != null && startsOn(ws, day)) {
      out.add(
        SeasonEvent(
          kind: SeasonEventKind.weatherSeason,
          date: day,
          days: i,
          itemId: ws.itemId,
        ),
      );
    }
    // سهيل والثريا: بداية سجلهما لا تُعدّ إن وُجد طلوعهما المحسوب لتلك
    // السنة؛ وإن تعذّر الحساب (null) تُعدّ بداية السجل في الجدول.
    final id = info.star.itemId;
    if (startsOn(info.star, day) &&
        !(rising != null && heliacal(id) && rising(id, day.year) != null)) {
      out.add(
        SeasonEvent(
          kind: SeasonEventKind.star,
          date: day,
          days: i,
          itemId: info.star.itemId,
        ),
      );
    }
    if (startsOn(info.majorSeason, day)) {
      out.add(
        SeasonEvent(
          kind: SeasonEventKind.majorSeason,
          date: day,
          days: i,
          itemId: info.majorSeason.itemId,
        ),
      );
    }
    final dar = info.dar;
    if (dar != null && startsOn(dar, day)) {
      out.add(
        SeasonEvent(
          kind: SeasonEventKind.dar,
          date: day,
          days: i,
          dar: dar,
        ),
      );
    }
  }

  if (rising != null) {
    final last = DateTime(start.year, start.month, start.day + horizon);
    for (final item in items.values) {
      if (item.dateMethod != DateMethod.heliacal) continue;
      for (final year in [start.year, start.year + 1]) {
        final utc = rising(item.id, year);
        if (utc == null) continue;
        final day = DateTime(utc.year, utc.month, utc.day);
        if (day.isBefore(start) || day.isAfter(last)) continue;
        out.add(
          SeasonEvent(
            kind: SeasonEventKind.star,
            date: day,
            days: DateTime.utc(day.year, day.month, day.day)
                .difference(DateTime.utc(start.year, start.month, start.day))
                .inDays,
            itemId: item.id,
            computed: true,
          ),
        );
      }
    }
  }

  out.sort((a, b) {
    final byDay = a.days.compareTo(b.days);
    return byDay != 0 ? byDay : a.kind.index.compareTo(b.kind.index);
  });
  return out;
}

/// العدّاد (DESIGN R2.8): ما بدأ اليوم نفسه إن وُجد، وإلا أقرب بداية قادمة
/// من مواسم الجو والطوالع والمواسم الكبيرة وطلوع سهيل/الثريا. لا الدرور.
SeasonEvent? countdownEvent(List<SeasonEvent> events) {
  for (final e in events) {
    if (e.kind != SeasonEventKind.dar) return e;
  }
  return null;
}

/// صفوف «القادم» (حتى 3، مرتبة بالأقرب): الدَّرّ التالي، والموسم الكبير
/// التالي، وأقرب موسم جو أو طالع غير هدف [countdown]. كلها بعد اليوم المعروض.
/// بلا درور (السعودية، R3.10): الطالع التالي، وموسم الجو التالي، والموسم
/// الكبير التالي.
List<SeasonEvent> upcomingEvents(
  List<SeasonEvent> events,
  SeasonEvent? countdown, {
  bool hasDurur = true,
}) {
  SeasonEvent? first(bool Function(SeasonEvent) test) {
    for (final e in events) {
      if (e.days > 0 && test(e)) return e;
    }
    return null;
  }

  if (!hasDurur) {
    return [
      first((e) => e.kind == SeasonEventKind.star),
      first((e) => e.kind == SeasonEventKind.weatherSeason),
      first((e) => e.kind == SeasonEventKind.majorSeason),
    ].whereType<SeasonEvent>().toList()
      ..sort((a, b) => a.days.compareTo(b.days));
  }
  final rows = [
    first((e) => e.kind == SeasonEventKind.dar),
    first((e) => e.kind == SeasonEventKind.majorSeason),
    first(
      (e) =>
          (e.kind == SeasonEventKind.weatherSeason ||
              e.kind == SeasonEventKind.star) &&
          !(countdown != null && e.sameAs(countdown)),
    ),
  ].whereType<SeasonEvent>().toList()
    ..sort((a, b) => a.days.compareTo(b.days));
  return rows;
}
