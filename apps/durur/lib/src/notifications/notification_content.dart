import '../../l10n/app_localizations.dart';
import '../domain/city.dart';
import '../domain/region.dart';
import '../domain/tables.dart';
import '../domain/weather_symbol.dart';
import '../features/common/weather_icon.dart';
import '../routing/app_routes.dart';
import 'notification_planner.dart';

/// تنبيه جاهز للجدولة: النص من ملف الترجمة والحمولة مسار صفحة العنصر.
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.fireAt,
    required this.kind,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;

  /// وقت الوصول بتوقيت الجهاز (الساعة 08:00).
  final DateTime fireAt;

  final NotificationKind kind;
  final String title;
  final String body;

  /// مسار go_router: `/item/<id>?from=…` أو `/dar/<regionId>/<MM-DD>?from=…`.
  final String payload;

  /// بصمة المحتوى (لاكتشاف أن الخطة لم تتغير).
  String get fingerprint => '$id|${fireAt.toIso8601String()}|$title|$body|'
      '$payload|${kind.name}';
}

/// يبني نص التنبيه وحمولته (DESIGN 8.9، §13 «التنبيهات»):
/// - سهيل والثريا بتاريخهما المحسوب: «طلع {النجم} اليوم في {المدينة}»،
///   والفعل والضمير حسب `item.gender` («طلعت الثريا…»، §13 «جنس النجم»).
/// - بقية المواسم المهمة: «دخل {الموسم} اليوم في {المنطقة}».
/// - بداية الدَّرّ: «بدأ دَرّ {الدَّرّ} من {المئة}»، وللمستعيرة «… حسب حساب
///   {المُعيرة}» (D24)، والنص «الجو المعتاد: …».
/// الحمولة تحمل تاريخ التنبيه (`from`) فتفتح الصفحة الفترة التي بدأت يومها.
ScheduledNotification buildScheduledNotification(
  PlannedNotification planned, {
  required AppLocalizations l10n,
  required Tables tables,
  required City city,
  required Region region,
}) {
  final from = planned.date;
  final String title;
  final String body;
  final String payload;
  switch (planned.subject) {
    case ItemSubject(:final item, :final heliacal):
      final name = item.name.ar;
      if (heliacal) {
        final gender = item.gender.code;
        title = l10n.notifStarTitle(gender, name, city.name.ar);
        body = l10n.notifStarBody(gender);
      } else {
        title = l10n.notifSeasonTitle(name, region.name.ar);
        body = l10n.notifSeasonBody(name);
      }
      payload = AppRoutes.item(item.id, from: from);
    case DarSubject(:final record, :final dururRegionId, :final borrowed):
      final hundred = tables.items[record.seasonId]?.name.ar ?? '';
      title = borrowed
          ? l10n.notifDarTitleBorrowed(
              record.name.ar,
              hundred,
              tables.region(dururRegionId)?.name.ar ?? dururRegionId,
            )
          : l10n.notifDarTitle(record.name.ar, hundred);
      body = record.weather.isEmpty
          ? ''
          : l10n.notifDarBody(_weatherList(l10n, record.weather));
      payload = AppRoutes.dar(dururRegionId, record.start, from: from);
  }
  return ScheduledNotification(
    id: planned.id,
    fireAt: planned.fireAt,
    kind: planned.kind,
    title: title,
    body: body,
    payload: payload,
  );
}

String _weatherList(AppLocalizations l10n, List<WeatherSymbol> symbols) =>
    symbols.map((s) => weatherSymbolLabel(l10n, s)).join(l10n.listSeparator);

/// هل [payload] مسار صفحة عنصر أو دَرّ؟ (لا يُفتح غير ذلك من تنبيه.)
bool isNotificationPayload(String? payload) {
  if (payload == null) return false;
  final uri = Uri.tryParse(payload);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.hasAbsolutePath) {
    return false;
  }
  final s = uri.pathSegments;
  return (s.length == 2 && s[0] == 'item' && s[1].isNotEmpty) ||
      (s.length == 3 && s[0] == 'dar' && s[1].isNotEmpty && s[2].isNotEmpty);
}
