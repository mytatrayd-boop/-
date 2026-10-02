import '../../../l10n/app_localizations.dart';
import '../../domain/day_info.dart';
import '../../domain/tables.dart';
import '../../formatting/date_labels.dart';
import '../../formatting/digits.dart';
import '../../hijri/umm_al_qura_calendar.dart';
import '../common/weather_icon.dart';

/// نصوص الشاشة الرئيسية المبنية من ملف الترجمة ونتيجة المحرك (الميزة 6).

/// سطر التاريخين (DESIGN 8.4): [single] في سطر واحد بفاصل «—»، و[first]
/// و[second] للعرض في سطرين بلا فاصل إن لم يتسع السطر. [second] null خارج
/// مدى جدول الهجري. لتاريخ غير اليوم يبدأ بـ «تعرض:».
typedef DatesLine = ({String single, String first, String? second});

DatesLine datesLines(
  AppLocalizations l10n,
  DateTime date,
  UmmAlQuraCalendar? hijri, {
  required bool isToday,
  DigitStyle digits = DigitStyle.arabicIndic,
}) {
  final h = hijri?.tryConvert(date);
  final gregorian = gregorianDateLabel(l10n, date, digits: digits);
  final weekday = weekdayLabel(l10n, date);
  String prefixed(String s) => isToday ? s : l10n.homeViewingDate(s);
  final first = prefixed('$weekday $gregorian');
  if (h == null) return (single: first, first: first, second: null);
  final hijriText = hijriDateLabel(l10n, h, digits: digits);
  return (
    single: prefixed(l10n.homeDatesLine(weekday, gregorian, hijriText)),
    first: first,
    second: hijriText,
  );
}

/// السطر الواحد من [datesLines].
String datesLine(
  AppLocalizations l10n,
  DateTime date,
  UmmAlQuraCalendar? hijri, {
  required bool isToday,
  DigitStyle digits = DigitStyle.arabicIndic,
}) => datesLines(l10n, date, hijri, isToday: isToday, digits: digits).single;

/// «اليوم ٤ من ١٠» بطول الدَّرّ الفعلي.
String dayOfDarLabel(
  AppLocalizations l10n,
  DayInfo info, {
  DigitStyle digits = DigitStyle.arabicIndic,
}) => l10n.homeDayOfDar(
  formatInteger(info.dar.dayNumber, digits),
  formatInteger(info.dar.length, digits),
);

/// قائمة أسماء رموز الجو، أو «لا يوجد».
String weatherListLabel(AppLocalizations l10n, DayInfo info) =>
    info.weather.isEmpty
    ? l10n.wheelA11yNone
    : info.weather
          .map((s) => weatherSymbolLabel(l10n, s))
          .join(l10n.listSeparator);

/// بادئة نص الدائرة لقارئ الشاشة (label): «اليوم» أو «التاريخ المعروض».
String dialSemanticsPrefix(AppLocalizations l10n, {required bool isToday}) =>
    isToday ? l10n.wheelA11yPrefixToday : l10n.wheelA11yPrefixViewing;

/// قيمة الدائرة لقارئ الشاشة (value، DESIGN 7.7): التاريخ بلا لاحقتي م وهـ،
/// ثم الجمل حسب المنطقة. اليوم داخل الدَّرّ بطوله الفعلي لا «من عشرة».
/// - درور خاصة: التاريخ ← الدَّرّ ← الموسم (إن اختلف عن مئة الدَّرّ، D25)
///   ← النجم ← موسم الجو ← الجو المعتاد.
/// - مستعيرة (D24، 7.8): التاريخ ← الموسم ← موسم الجو ← النجم ← الدَّرّ
///   المستعار باسم المُعيرة ← الجو المعتاد.
String dialSemanticsValue(
  AppLocalizations l10n,
  DayInfo info,
  Tables tables, {
  DigitStyle digits = DigitStyle.arabicIndic,
}) {
  String name(String? id) => tables.items[id]?.name.ar ?? '';
  final date = info.date;
  final h = tables.hijri?.tryConvert(date);
  final weekday = weekdayLabel(l10n, date);
  final gregorian = l10n.gregorianDateSpoken(
    formatInteger(date.day, digits),
    'g${date.month}',
    formatInteger(date.year, digits),
  );
  // بلا تاريخ هجري (خارج مدى الجدول) لا تُقال كلمة «هجري».
  final dateSentence = h == null
      ? l10n.wheelA11yDateValueNoHijri(weekday, gregorian)
      : l10n.wheelA11yDateValue(
          weekday,
          gregorian,
          l10n.hijriDateSpoken(
            formatInteger(h.day, digits),
            'm${h.month}',
            formatInteger(h.year, digits),
          ),
        );
  final day = formatInteger(info.dar.dayNumber, digits);
  final total = formatInteger(info.dar.length, digits);
  final star = l10n.wheelA11yStar(name(info.star.itemId));
  final ws = l10n.wheelA11yWeatherSeason(
    info.weatherSeason == null
        ? l10n.wheelA11yNone
        : name(info.weatherSeason!.itemId),
  );
  final weather = l10n.wheelA11yWeather(weatherListLabel(l10n, info));
  final hundred = name(info.dar.record.seasonId);
  final major = l10n.wheelA11yMajorSeason(name(info.majorSeason.itemId));
  if (info.borrowsDurur) {
    final lender = tables.region(info.dururRegionId)?.name.ar ?? '';
    return [
      dateSentence,
      major,
      ws,
      star,
      l10n.wheelA11yDarBorrowed(info.dar.name.ar, hundred, lender, day, total),
      weather,
    ].join(' ');
  }
  return [
    dateSentence,
    l10n.wheelA11yDar(info.dar.name.ar, hundred, day, total),
    if (info.majorSeason.itemId != info.dar.record.seasonId) major,
    star,
    ws,
    weather,
  ].join(' ');
}

/// النص الكامل كما يُسمع (label ثم value)، مثل: «اليوم: الجمعة، …».
String dialSemanticsLabel(
  AppLocalizations l10n,
  DayInfo info,
  Tables tables, {
  required bool isToday,
  DigitStyle digits = DigitStyle.arabicIndic,
}) =>
    '${dialSemanticsPrefix(l10n, isToday: isToday)}: '
    '${dialSemanticsValue(l10n, info, tables, digits: digits)}';
