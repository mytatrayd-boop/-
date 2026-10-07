import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/day_info.dart';
import '../../domain/item.dart';
import '../../domain/tables.dart';
import '../../domain/weather_symbol.dart';
import '../../formatting/date_labels.dart';
import '../../formatting/digits.dart';
import '../../theme/app_theme.dart';
import '../common/glass.dart';
import '../common/weather_icon.dart';
import 'day_text.dart';
import 'season_events.dart';

/// مكوّنات الشاشة الرئيسية تحت الدائرة (DESIGN R2.8): صف العدّاد، وبطاقات
/// الطالع والجو المعتاد والزراعة والقادم، وشريط الدَّرّ. كلها أسطح زجاجية.
abstract final class HomeCardKeys {
  static const countdown = Key('homeCountdown');
  static const starCard = Key('homeStarCard');
  static const weatherCard = Key('homeWeatherCard');
  static const darStrip = Key('homeDarStrip');
  static const darSeasonChip = Key('homeDarSeasonChip');
  static const liveWeatherCard = Key('homeLiveWeatherCard');
  static const usualWeatherCard = Key('homeUsualWeatherCard');
  static const agriCard = Key('homeAgriCard');
  static const agriKnowSource = Key('homeAgriKnowSource');
  static const upcomingCard = Key('homeUpcomingCard');
  static Key upcomingRow(int i) => Key('homeUpcomingRow$i');
  static Key weatherChip(WeatherSymbol s) => Key('homeWeatherChip_${s.code}');
}

/// «اليوم ٨ من ١٠»، «الجمعة ١٦ أكتوبر» … نصوص مشتركة.
String weekdayDayMonth(
  AppLocalizations l10n,
  DateTime date,
  DigitStyle digits,
) => l10n.weekdayDayMonth(
  weekdayLabel(l10n, date),
  l10n.dayMonthDate(formatInteger(date.day, digits), 'g${date.month}'),
);

/// اسم الحدث كما يظهر في العدّاد و«القادم».
String seasonEventName(
  AppLocalizations l10n,
  Tables tables,
  SeasonEvent e,
) => e.kind == SeasonEventKind.dar
    ? l10n.darTitle(e.dar!.name.ar)
    : tables.items[e.itemId]?.name.ar ?? '';

/// العدّاد (DESIGN R3.1-17): بطاقة زجاجية 200×84 في الوسط: «٩» Almarai 800
/// 30 cyan متوهج + «أيام» 15، ثم «على دخول الوسم» 15، ثم «الجمعة ١٦ أكتوبر»
/// 12 `ink-soft`. يوم البداية نفسه: «دخل الوسم اليوم». بالأيام لا بالساعات.
class CountdownCard extends StatelessWidget {
  const CountdownCard({
    super.key,
    required this.event,
    required this.tables,
    required this.digits,
    required this.cityName,
    required this.viewing,
    required this.onTap,
  });

  final SeasonEvent event;
  final Tables tables;
  final DigitStyle digits;
  final String? cityName;

  /// التاريخ المعروض إن كان غير اليوم (يضاف «من {التاريخ}»).
  final DateTime? viewing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DururColors.of(context);
    final item = tables.items[event.itemId];
    final name = seasonEventName(l10n, tables, event);
    final gender = item?.gender.code ?? StarGender.masculine.code;
    final isStar = event.kind == SeasonEventKind.star;
    final date = weekdayDayMonth(l10n, event.date, digits);
    final from = viewing == null
        ? null
        : l10n.countdownFromDate(
            gregorianDateLabel(l10n, viewing!, digits: digits),
          );
    TextStyle body(double size, Color color, [FontWeight w = FontWeight.w700]) =>
        TextStyle(
          fontFamily: DururFonts.body,
          fontSize: size,
          fontWeight: w,
          color: color,
          height: 1.25,
        );

    final List<Widget> lines;
    final String spoken;
    if (event.days == 0) {
      final text = !isStar
          ? l10n.countdownSeasonToday(name)
          : event.computed && cityName != null
          ? l10n.countdownStarTodayIn(gender, name, cityName!)
          : l10n.countdownStarToday(gender, name);
      lines = [
        Text(
          text,
          textAlign: TextAlign.center,
          style: body(15, colors.primary, FontWeight.w800).copyWith(
            shadows: textGlow(colors.primary),
          ),
        ),
        Text(date, style: body(12, colors.inkSoft)),
      ];
      spoken = [text, date].join(l10n.listSeparator);
    } else {
      final target = isStar
          ? l10n.countdownToStar(name)
          : l10n.countdownToSeason(name);
      final showNumber = event.days > 2;
      lines = [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            if (showNumber)
              Text(
                formatInteger(event.days, digits),
                style: TextStyle(
                  fontFamily: DururFonts.body,
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  height: 1.1,
                  color: colors.primary,
                  shadows: textGlow(colors.primary),
                ),
              ),
            Text(l10n.countdownDaysUnit(event.days), style: body(15, colors.ink)),
          ],
        ),
        Text(target, textAlign: TextAlign.center, style: body(15, colors.ink)),
        Text(date, style: body(12, colors.inkSoft)),
      ];
      spoken = l10n.countdownA11y(
        l10n.countdownDaysPhrase(event.days, formatInteger(event.days, digits)),
        target,
        date,
      );
    }

    return Semantics(
      key: HomeCardKeys.countdown,
      button: true,
      label: [spoken, ?from].join(l10n.listSeparator),
      excludeSemantics: true,
      onTap: onTap,
      child: GlassSurface(
        blur: true,
        radius: 12,
        borderColor: colors.primary.withValues(alpha: 0.5),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84 - 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...lines,
              if (from != null)
                Text(from, style: body(12, colors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر دائري زجاجي مرئي 36dp بمنطقة لمس 48dp (السابق/التالي، R3.1-17)، بوصف
/// لقارئ الشاشة، وضغطة مطوّلة تقفز دَرّاً (أو طالعاً بلا درور، 7.5).
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.label,
    required this.glyph,
    required this.onTap,
    this.onLongPress,
  });

  final String label;

  /// «›» أو «‹» (السهم يشير لاتجاه الزمن في RTL، DESIGN 7.5).
  final String glyph;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox.square(
        dimension: 48,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onTap,
            onLongPress: onLongPress,
            radius: 24,
            child: Center(
              child: SizedBox.square(
                dimension: 36,
                child: GlassSurface(
                  radius: 18,
                  padding: EdgeInsets.zero,
                  child: Center(
                    child: Text(
                      glyph,
                      style: TextStyle(
                        fontFamily: DururFonts.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        height: 1,
                        color: colors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حد البطاقة في R3: `#8FB3C0` شفافية 40%، 1dp.
const cardBorder = Color(0x668FB3C0);

/// بطاقة زجاجية بشكل R3.1-15: زوايا 12، حشوة 12، حد `#8FB3C0` 40%. الرأس:
/// عنوان 15 `ink` وتحته فرعي 12 `ink-soft` في البداية، ومربع أيقونة 32dp في
/// النهاية.
class R3Card extends StatelessWidget {
  const R3Card({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.onTap,
    this.minHeight = 0,
  });

  final String title;
  final String? subtitle;
  final Widget? icon;
  final List<Widget> children;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    return GlassSurface(
      blur: true,
      radius: 12,
      borderColor: cardBorder,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: math.max(0, minHeight - 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: DururFonts.body,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: DururFonts.body,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: colors.inkSoft,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.ink.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SizedBox.square(dimension: 20, child: icon),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// بطاقة «الطالع» (R3.1-16، مقابل «مراحل النجوم»): صف 4 خانات (الطالع
/// الحالي ثم الثلاثة التالية)، ثم الاسم 15 gold، و«الموسم: …»، وسطر الطلوع
/// لسهيل والثريا. الخانة تفتح صفحة طالعها، وبقية البطاقة الطالع الحالي.
class StarCard extends StatelessWidget {
  const StarCard({
    super.key,
    required this.info,
    required this.tables,
    required this.nextStars,
    required this.onTap,
    required this.onStar,
    this.risingLine,
  });

  final DayInfo info;
  final Tables tables;

  /// معرّفات الطوالع التالية (حتى 3).
  final List<String> nextStars;
  final VoidCallback onTap;
  final ValueChanged<String> onStar;

  /// «طلع في الرياض قبل … يوماً» لسهيل والثريا، وإلا null.
  final String? risingLine;

  static Key slotKey(int i) => Key('homeStarSlot$i');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DururColors.of(context);
    String name(String? id) => tables.items[id]?.name.ar ?? '';
    final slots = [info.star.itemId, ...nextStars.take(3)];
    TextStyle small(Color c, [double size = 11]) => TextStyle(
      fontFamily: DururFonts.body,
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: c,
      height: 1.25,
    );
    return R3Card(
      key: HomeCardKeys.starCard,
      title: l10n.cardStarTitle,
      subtitle: l10n.cardStarSubtitle,
      icon: CustomPaint(painter: _StarPainter(colors.goldText)),
      onTap: onTap,
      minHeight: 150,
      children: [
        Row(
          children: [
            for (final (i, id) in slots.indexed)
              Expanded(
                child: Semantics(
                  button: true,
                  label: name(id),
                  excludeSemantics: true,
                  child: InkWell(
                    key: slotKey(i),
                    onTap: () => onStar(id),
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox.square(
                            dimension: i == 0 ? 24 : 20,
                            child: CustomPaint(
                              painter: _StarPainter(
                                i == 0 ? colors.goldText : colors.inkSoft,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name(id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: small(i == 0 ? colors.ink : colors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name(info.star.itemId),
          style: TextStyle(
            fontFamily: DururFonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: colors.goldText,
            height: 1.3,
          ),
        ),
        Text(
          l10n.homeSeasonLabel(name(info.majorSeason.itemId)),
          style: small(colors.inkSoft, 12),
        ),
        if (risingLine != null)
          Text(risingLine!, style: small(colors.goldText, 12)),
      ],
    );
  }
}

/// بطاقة «الطقس» الفعلي (R3.8، D42): مكانها وشكلها فقط الآن، بحالة «غير
/// متاح بعد». الجلب من الشبكة والموقع في الجزء ب. لا مصطلح تراثي فيها.
class LiveWeatherCard extends StatelessWidget {
  const LiveWeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DururColors.of(context);
    return R3Card(
      key: HomeCardKeys.liveWeatherCard,
      title: l10n.cardLiveWeatherTitle,
      subtitle: l10n.cardLiveWeatherSubtitle,
      icon: WeatherIcon(
        WeatherSymbol.cloud,
        color: colors.inkSoft,
      ),
      minHeight: 200,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Text(
            l10n.cardLiveWeatherUnavailable,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: DururFonts.body,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// «الجو المعتاد حسب التراث» (R3.1-18): العنوان 13، ثم شرائح الجو (رمز
/// ملوّن 18 + كلمة 13)، ثم «حسب التراث، وليس توقعاً للطقس.» 12. الشريحة تفتح
/// فقاعة الرمز. لا يوضع في بطاقة الطقس الفعلي ولا بجانبها.
class UsualWeatherSection extends StatelessWidget {
  const UsualWeatherSection({
    super.key,
    required this.info,
    required this.onSymbol,
  });

  final DayInfo info;

  /// ضغطة شريحة: الرمز وموضعها على الشاشة لفقاعته.
  final void Function(WeatherSymbol symbol, Rect anchor) onSymbol;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DururColors.of(context);
    return Column(
      key: HomeCardKeys.weatherCard,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.usualWeatherHeritageTitle,
            style: TextStyle(
              fontFamily: DururFonts.body,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.inkSoft,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final s in info.weather)
              _WeatherBubbleChip(
                key: HomeCardKeys.weatherChip(s),
                symbol: s,
                onTap: onSymbol,
              ),
          ],
        ),
        Text(
          l10n.cardWeatherNote,
          style: TextStyle(
            fontFamily: DururFonts.body,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colors.inkSoft,
          ),
        ),
      ],
    );
  }
}

/// بطاقة «الجو المعتاد حسب التراث» بعرض كامل في منطقة بلا درور (R3.10، بدل
/// شريط الدَّرّ). الضغط عليها يفتح صفحة الطالع الحالي.
class UsualWeatherCard extends StatelessWidget {
  const UsualWeatherCard({
    super.key,
    required this.info,
    required this.onTap,
    required this.onSymbol,
  });

  final DayInfo info;
  final VoidCallback onTap;
  final void Function(WeatherSymbol symbol, Rect anchor) onSymbol;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      key: HomeCardKeys.usualWeatherCard,
      blur: true,
      radius: 12,
      borderColor: cardBorder,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      child: UsualWeatherSection(info: info, onSymbol: onSymbol),
    );
  }
}

class _WeatherBubbleChip extends StatelessWidget {
  const _WeatherBubbleChip({
    super.key,
    required this.symbol,
    required this.onTap,
  });

  final WeatherSymbol symbol;
  final void Function(WeatherSymbol symbol, Rect anchor) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    final l10n = AppLocalizations.of(context);
    void tap() {
      final box = context.findRenderObject() as RenderBox?;
      final rect = box == null
          ? Rect.zero
          : box.localToGlobal(Offset.zero) & box.size;
      onTap(symbol, rect);
    }

    return Semantics(
      button: true,
      label: weatherSymbolLabel(l10n, symbol),
      excludeSemantics: true,
      onTap: tap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: colors.glassStroke),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WeatherIcon(
                    symbol,
                    size: 18,
                    color: colors.weatherTone(symbol.code),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      weatherSymbolLabel(l10n, symbol),
                      style: TextStyle(
                        fontFamily: DururFonts.body,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط الدَّرّ بعرض كامل (DESIGN R2.8 بند 7، R3.1-18): «دَرّ الستين» +
/// شريحة «من الصفري»؛ شريط التقدم بلون المئة؛ «اليوم ٨ من ١٠»؛ ثم بعد خط
/// فاصل صف «الجو المعتاد حسب التراث». الضغط ← صفحة الدَّرّ، والشريحة ←
/// صفحة موسم المئة. لا يُعرض في منطقة بلا درور (R3.10).
class DarStrip extends StatelessWidget {
  const DarStrip({
    super.key,
    required this.info,
    required this.dar,
    required this.tables,
    required this.digits,
    required this.onTap,
    required this.onSeason,
    required this.onSymbol,
  });

  final DayInfo info;
  final DarPeriod dar;
  final Tables tables;
  final DigitStyle digits;
  final VoidCallback onTap;
  final VoidCallback onSeason;
  final void Function(WeatherSymbol symbol, Rect anchor) onSymbol;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final hundred = dar.record.seasonId;
    final tone = colors.season(hundred);
    return GlassSurface(
      key: HomeCardKeys.darStrip,
      blur: true,
      radius: 12,
      borderColor: cardBorder,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.darTitle(dar.name.ar),
                style: theme.textTheme.titleMedium,
              ),
              ActionChip(
                key: HomeCardKeys.darSeasonChip,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                backgroundColor: tone.withValues(alpha: 0.12),
                side: BorderSide.none,
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: tone,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(
                  l10n.darOfSeason(tables.items[hundred]?.name.ar ?? ''),
                  style: theme.textTheme.labelMedium,
                ),
                onPressed: onSeason,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DarProgress(dar: dar, color: tone),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  dayOfDarLabel(l10n, dar, digits: digits),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.ink,
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  '‹',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: colors.glassStroke),
          const SizedBox(height: 8),
          UsualWeatherSection(info: info, onSymbol: onSymbol),
        ],
      ),
    );
  }
}

/// شريط التقدم في الدَّرّ: مقطع لكل يوم بطوله الفعلي، يملأ من البداية
/// (اليمين في RTL)، واليوم الحالي بنقطة gold فوقه (DESIGN 5.6).
class _DarProgress extends StatelessWidget {
  const _DarProgress({required this.dar, required this.color});

  final DarPeriod dar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    final total = dar.length;
    final day = dar.dayNumber;
    return ExcludeSemantics(
      child: SizedBox(
        height: 14,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 1; i <= total; i++) ...[
              if (i > 1) const SizedBox(width: 3),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (i == day)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsetsDirectional.only(bottom: 0),
                        decoration: BoxDecoration(
                          color: colors.goldDeco,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= day ? color : colors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// بطاقة «مواسم الزراعة» (DESIGN R2.7، SPEC 15.5): لا بيانات زراعية معتمدة
/// بعد، فتعرض النص بالضبط «لا توجد بيانات زراعية موثقة لمنطقتك» وزر «أعرف
/// مصدراً» يفتح البلاغ معبأً باسم المنطقة.
class AgriCard extends StatelessWidget {
  const AgriCard({super.key, required this.onKnowSource, this.regionName});

  final VoidCallback onKnowSource;

  /// العنوان الفرعي: اسم المنطقة (R3.1-16).
  final String? regionName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DururColors.of(context);
    return R3Card(
      key: HomeCardKeys.agriCard,
      title: l10n.cardAgriTitle,
      subtitle: regionName,
      icon: CustomPaint(painter: _SproutPainter(colors.agri)),
      minHeight: 150,
      children: [
        Text(
          l10n.agriNoData,
          style: TextStyle(
            fontFamily: DururFonts.body,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.ink,
            height: 1.4,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: HomeCardKeys.agriKnowSource,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 48),
            ),
            onPressed: onKnowSource,
            child: Text(l10n.agriKnowSource),
          ),
        ),
      ],
    );
  }
}

/// بطاقة «القادم» (R3.1-16، مقابل «أحداث الطقس والعلامات التراثية»): 3
/// صفوف 48dp مرتبة بالأقرب: أيقونة النوع 18 ثم الاسم 13، و«بعد ٣ أيام» 12
/// في النهاية. الصف ← صفحة العنصر.
class UpcomingCard extends StatelessWidget {
  const UpcomingCard({
    super.key,
    required this.events,
    required this.tables,
    required this.digits,
    required this.onOpen,
  });

  final List<SeasonEvent> events;
  final Tables tables;
  final DigitStyle digits;
  final ValueChanged<SeasonEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DururColors.of(context);
    Widget iconFor(SeasonEvent e) {
      if (e.kind == SeasonEventKind.star) {
        return CustomPaint(painter: _StarPainter(colors.goldText));
      }
      final symbols = e.dar?.record.weather ??
          tables.items[e.itemId]?.weather ??
          const <WeatherSymbol>[];
      if (symbols.isEmpty) {
        return CustomPaint(painter: _StarPainter(colors.inkSoft));
      }
      return WeatherIcon(
        symbols.first,
        size: 18,
        color: colors.weatherTone(symbols.first.code),
      );
    }

    return R3Card(
      key: HomeCardKeys.upcomingCard,
      title: l10n.cardUpcomingTitle,
      subtitle: l10n.cardUpcomingSubtitle,
      minHeight: 200,
      children: [
        for (final (i, e) in events.indexed)
          InkWell(
            key: HomeCardKeys.upcomingRow(i),
            onTap: () => onOpen(e),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: colors.line)),
              ),
              child: Row(
                children: [
                  SizedBox.square(dimension: 18, child: iconFor(e)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      seasonEventName(l10n, tables, e),
                      style: TextStyle(
                        fontFamily: DururFonts.body,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l10n.upcomingAfter(e.days, formatInteger(e.days, digits)),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: DururFonts.body,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: colors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      fourPointStar(size.center(Offset.zero), size.shortestSide * 0.45),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

/// شتلة بورقتين (رمز الزراعة، R2.7) على شبكة 24.
class _SproutPainter extends CustomPainter {
  const _SproutPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(12, 21), const Offset(12, 12), p);
    canvas.drawPath(
      Path()
        ..moveTo(12, 12)
        ..cubicTo(12, 8, 9, 6, 5, 6)
        ..cubicTo(5, 10, 8, 12, 12, 12),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 14)
        ..cubicTo(12, 10.5, 14.5, 8.5, 18.5, 8.5)
        ..cubicTo(18.5, 12, 16, 14, 12, 14),
      p,
    );
  }

  @override
  bool shouldRepaint(_SproutPainter old) => old.color != color;
}
