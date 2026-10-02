import 'localized_text.dart';
import 'record_meta.dart';
import 'region_table.dart';
import 'weather_symbol.dart';

/// فترة فعّالة ليوم معيّن، بتواريخها الفعلية في تلك السنة.
class ActivePeriod {
  const ActivePeriod({
    required this.start,
    required this.end,
    required this.dayNumber,
  });

  /// أول يوم (UTC، منتصف الليل).
  final DateTime start;

  /// آخر يوم شامل (UTC، منتصف الليل).
  final DateTime end;

  /// رقم اليوم داخل الفترة، يبدأ من 1.
  final int dayNumber;

  /// عدد أيام الفترة (يشمل 29 فبراير إن وقع فيها).
  int get length => end.difference(start).inDays + 1;
}

/// الدَّرّ الفعّال ليوم.
class DarPeriod extends ActivePeriod {
  const DarPeriod({
    required this.record,
    required super.start,
    required super.end,
    required super.dayNumber,
  });

  final DarRecord record;

  LocalizedText get name => record.name;
  int get number => record.number;
}

/// فترة عنصر (موسم كبير، نجم، موسم جو) فعّالة ليوم.
class ItemPeriod extends ActivePeriod {
  const ItemPeriod({
    required this.itemId,
    required super.start,
    required super.end,
    required super.dayNumber,
    this.record,
  });

  final String itemId;

  /// سجل الجدول الذي جاءت منه الفترة (لمصدر التواريخ واعتمادها، الميزة 7).
  final Sourced? record;
}

/// نتيجة محرك الحساب ليوم في منطقة (الميزة 1).
class DayInfo {
  const DayInfo({
    required this.date,
    required this.regionId,
    String? dururRegionId,
    required this.dar,
    required this.majorSeason,
    required this.weatherSeason,
    required this.star,
  }) : dururRegionId = dururRegionId ?? regionId;

  /// اليوم المحلي بصيغة UTC منتصف الليل.
  final DateTime date;
  final String regionId;

  /// منطقة جدول الدرور الفعلي: المُعيرة عند الاستعارة (D24)، وإلا [regionId].
  final String dururRegionId;

  /// هل الدَّرّ مستعار من جدول منطقة أخرى؟ (D24)
  bool get borrowsDurur => dururRegionId != regionId;

  final DarPeriod dar;
  final ItemPeriod majorSeason;

  /// موسم الجو إن وُجد (قد توجد أيام بلا موسم جو).
  final ItemPeriod? weatherSeason;
  final ItemPeriod star;

  /// رموز الجو المعتاد (من الدَّرّ).
  List<WeatherSymbol> get weather => dar.record.weather;
  LocalizedText? get weatherNote => dar.record.weatherNote;
}
