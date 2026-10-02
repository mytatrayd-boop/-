import '../astronomy/heliacal.dart';
import '../domain/item.dart';
import '../domain/local_date.dart';
import '../domain/region_table.dart';
import '../engine/calendar_engine.dart';

/// مخطِّط التنبيهات المحلية (الميزة 8، ARCHITECTURE §9، D13). Dart صافٍ:
/// يحسب ما يُجدول ومتى، بلا نصوص (النصوص من ملف الترجمة في طبقة الواجهة)
/// وبلا البلجن. حتمي: المدخلات نفسها تعطي الخطة نفسها بالمعرّفات نفسها.

/// نوع التنبيه، ولكل نوع مفتاح مستقل وقناة أندرويد مستقلة (SPEC 8 معيار 1-2).
enum NotificationKind {
  /// المواسم المهمة (عناصر `important: true`).
  important,

  /// بداية كل دَرّ.
  dar,
}

/// موضوع التنبيه: عنصر من items.json أو سجل دَرّ.
sealed class NotificationSubject {
  const NotificationSubject();
}

/// دخول عنصر مهم. [heliacal]: التاريخ من الحساب الفلكي لمدينة المستخدم
/// (سهيل والثريا، الميزة 5)؛ false إن كان من جدول المنطقة.
final class ItemSubject extends NotificationSubject {
  const ItemSubject(this.item, {required this.heliacal});

  final Item item;
  final bool heliacal;

  @override
  bool operator ==(Object other) =>
      other is ItemSubject &&
      other.item.id == item.id &&
      other.heliacal == heliacal;

  @override
  int get hashCode => Object.hash(item.id, heliacal);
}

/// بداية دَرّ. [dururRegionId] جدول الدرور الفعلي (المُعيرة عند الاستعارة،
/// D24)، و[borrowed] هل الدرور مستعارة لمنطقة المستخدم.
final class DarSubject extends NotificationSubject {
  const DarSubject(
    this.record, {
    required this.dururRegionId,
    required this.borrowed,
  });

  final DarRecord record;
  final String dururRegionId;
  final bool borrowed;

  @override
  bool operator ==(Object other) =>
      other is DarSubject &&
      other.dururRegionId == dururRegionId &&
      other.record.start == record.start &&
      other.borrowed == borrowed;

  @override
  int get hashCode => Object.hash(dururRegionId, record.start, borrowed);
}

/// تنبيه في الخطة.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.date,
    required this.kind,
    required this.subject,
  });

  /// معرّف ثابت: `yyyymmdd * 100 + slot` (ضمن int32 حتى سنة 2147).
  final int id;

  /// اليوم المحلي (منتصف الليل) الذي يصل فيه التنبيه.
  final DateTime date;

  final NotificationKind kind;
  final NotificationSubject subject;

  /// لحظة الوصول بتوقيت الجهاز: الساعة 08:00 من [date] (SPEC 8 معيار 3).
  DateTime get fireAt => DateTime(
    date.year,
    date.month,
    date.day,
    NotificationPlanner.hour,
  );

  @override
  String toString() =>
      'PlannedNotification($id, ${date.toIso8601String()}, $kind)';
}

/// معرّفات العناصر المحسوبة فلكياً وحقلها في [HeliacalDates].
DateTime? heliacalDateOf(String itemId, HeliacalDates? dates) =>
    switch (itemId) {
      'suhail' => dates?.suhail,
      'thurayya' => dates?.thurayya,
      _ => null,
    };

class NotificationPlanner {
  const NotificationPlanner();

  /// حد التنبيهات المعلقة (حد آيفون 64، مع هامش 4، D13).
  static const maxPending = 60;

  /// أفق الجدولة بالأيام من اليوم (سنة).
  static const horizonDays = 365;

  /// ساعة الوصول بتوقيت الجهاز.
  static const hour = 8;

  /// هامش بعد الساعة 8:00 يبقى فيه تنبيه اليوم في الخطة: الجدولة غير
  /// الدقيقة قد تؤخره، وفتح التطبيق بين 8:00 ووصوله لا يجوز أن يلغيه
  /// (المُجدوِل يعيده فقط إن كان ما يزال معلقاً).
  static const lateMargin = Duration(hours: 1);

  /// الخطة من [now] (وقت الجهاز): كل بداية تقع في الأيام
  /// `[اليوم، اليوم + 364]` ولم يمضِ على ساعتها أكثر من [lateMargin]، مرتبة زمنياً ومقصوصة إلى
  /// [maxPending].
  ///
  /// - [important]: العناصر المهمة (`important: true`) في كل الطبقات؛ ما
  ///   طريقته `heliacal` (سهيل والثريا) يؤخذ تاريخه من [heliacal] لسنته، وإن
  ///   تعذّر الحساب (null) يُستعمل تاريخ بدايته في جدول المنطقة.
  /// - [dar]: بداية كل دَرّ من جدول الدرور الفعلي (المُعيرة عند الاستعارة).
  /// - لا يتكرر (الموضوع، اليوم).
  List<PlannedNotification> plan({
    required DateTime now,
    required CalendarEngine engine,
    required Map<String, Item> items,
    required HeliacalDates? Function(int year) heliacal,
    required bool important,
    required bool dar,
  }) {
    if (!important && !dar) return const [];
    final today = dateOnly(now);
    final last = addDays(today, horizonDays - 1);
    bool inHorizon(DateTime day) {
      final d = dateOnly(day);
      if (d.isBefore(today) || d.isAfter(last)) return false;
      return DateTime(d.year, d.month, d.day, hour).add(lateMargin).isAfter(now);
    }

    final entries = <(DateTime, NotificationKind, NotificationSubject)>[];
    final seen = <(DateTime, NotificationSubject)>{};
    void add(DateTime day, NotificationKind kind, NotificationSubject s) {
      final d = dateOnly(day);
      if (!inHorizon(d) || !seen.add((d, s))) return;
      entries.add((d, kind, s));
    }

    final heliacalItems = [
      for (final item in items.values)
        if (important && item.important && item.dateMethod == DateMethod.heliacal)
          item,
    ];
    // سنوات تشمل الأفق: سنة اليوم والتي بعدها.
    final years = {today.year, last.year};
    final heliacalByYear = {for (final y in years) y: heliacal(y)};
    // عناصر فلكية بلا تاريخ محسوب لسنة ← تاريخ الجدول لتلك السنة.
    final fallbackYears = <String, Set<int>>{};
    for (final item in heliacalItems) {
      for (final y in years) {
        final date = heliacalDateOf(item.id, heliacalByYear[y]);
        if (date == null) {
          (fallbackYears[item.id] ??= {}).add(y);
        } else {
          add(
            DateTime(date.year, date.month, date.day),
            NotificationKind.important,
            ItemSubject(item, heliacal: true),
          );
        }
      }
    }

    bool tableImportant(String itemId, int year) {
      final item = items[itemId];
      if (item == null || !item.important) return false;
      if (item.dateMethod == DateMethod.table) return true;
      return fallbackYears[itemId]?.contains(year) ?? false;
    }

    for (var day = today; !day.isAfter(last); day = addDays(day, 1)) {
      final info = engine.resolve(day);
      if (important) {
        for (final period in [
          info.majorSeason,
          info.star,
          ?info.weatherSeason,
        ]) {
          if (period.dayNumber == 1 && tableImportant(period.itemId, day.year)) {
            add(
              day,
              NotificationKind.important,
              ItemSubject(items[period.itemId]!, heliacal: false),
            );
          }
        }
      }
      if (dar && info.dar.dayNumber == 1) {
        add(
          day,
          NotificationKind.dar,
          DarSubject(
            info.dar.record,
            dururRegionId: info.dururRegionId,
            borrowed: info.borrowsDurur,
          ),
        );
      }
    }

    // ترتيب زمني؛ وفي اليوم نفسه المواسم المهمة قبل الدَّرّ ثم بالمعرّف.
    String key(NotificationSubject s) => switch (s) {
      ItemSubject(:final item) => item.id,
      DarSubject(:final dururRegionId, :final record) =>
        '$dururRegionId/${record.start}',
    };
    entries.sort((a, b) {
      final byDate = a.$1.compareTo(b.$1);
      if (byDate != 0) return byDate;
      final byKind = a.$2.index.compareTo(b.$2.index);
      if (byKind != 0) return byKind;
      return key(a.$3).compareTo(key(b.$3));
    });

    final result = <PlannedNotification>[];
    DateTime? slotDay;
    var slot = 0;
    for (final (day, kind, subject) in entries.take(maxPending)) {
      slot = day == slotDay ? slot + 1 : 0;
      slotDay = day;
      result.add(
        PlannedNotification(
          id: (day.year * 10000 + day.month * 100 + day.day) * 100 + slot,
          date: day,
          kind: kind,
          subject: subject,
        ),
      );
    }
    return result;
  }
}
