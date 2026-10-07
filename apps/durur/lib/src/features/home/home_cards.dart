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
  static const borrowNote = Key('dururBorrowNote');
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

/// العدّاد (DESIGN R2.8): «باقي» ← الرقم 34 cyan متوهج + «أيام» ← «على دخول
/// الوسم» ← «الجمعة ١٦ أكتوبر». يوم البداية نفسه: «دخل الوسم اليوم».
/// بالأيام لا بالساعات، بلا حركة دائمة.
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
    final theme = Theme.of(context);
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
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.primary,
            shadows: textGlow(colors.primary),
          ),
        ),
        Text(date, style: theme.textTheme.bodySmall),
      ];
      spoken = [text, date].join(l10n.listSeparator);
    } else {
      final target = isStar
          ? l10n.countdownToStar(name)
          : l10n.countdownToSeason(name);
      final showNumber = event.days > 2;
      lines = [
        Text(l10n.countdownRemaining, style: theme.textTheme.bodySmall),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            if (showNumber)
              Text(
                formatInteger(event.days, digits),
                style: TextStyle(
                  fontFamily: DururFonts.body,
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                  height: 44 / 34,
                  color: colors.primary,
                  shadows: textGlow(colors.primary),
                ),
              ),
            Text(
              l10n.countdownDaysUnit(event.days),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Text(
          target,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge,
        ),
        Text(date, style: theme.textTheme.bodySmall),
      ];
      spoken = l10n.countdownA11y(
        l10n.countdownDaysPhrase(
          event.days,
          formatInteger(event.days, digits),
        ),
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
        borderColor: colors.primary.withValues(alpha: 0.5),
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80, minWidth: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...lines,
              if (from != null) Text(from, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر دائري زجاجي 48dp (السابق/التالي) بوصف لقارئ الشاشة، وضغطة مطوّلة
/// تقفز دَرّاً (DESIGN 7.5).
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
            child: GlassSurface(
              radius: 24,
              padding: EdgeInsets.zero,
              child: Center(
                child: Text(
                  glyph,
                  style: TextStyle(
                    fontFamily: DururFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    height: 1,
                    color: colors.ink,
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

/// بطاقة زجاجية بعنوان (DESIGN R2.8): زوايا 20، حشوة 16، عنوان 15 `ink-soft`
/// مع أيقونة 20، وسهم «‹» إن كانت قابلة للضغط.
class _TitledCard extends StatelessWidget {
  const _TitledCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.onTap,
  });

  final String title;
  final Widget? icon;
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    return GlassSurface(
      blur: true,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                SizedBox.square(dimension: 20, child: icon),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.inkSoft,
                    ),
                  ),
                ),
              ),
              if (onTap != null)
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
          ...children,
        ],
      ),
    );
  }
}

/// بطاقة «الطالع» (DESIGN R2.8): نجمة gold + «الطالع»؛ الاسم Amiri 26 gold؛
/// «الموسم: …» بنقطة لونه؛ «موسم الجو: …» (أو «لا يوجد»)؛ ولسهيل/الثريا سطر
/// الطلوع المحسوب لمدينة المستخدم. الضغط ← صفحة الطالع.
class StarCard extends StatelessWidget {
  const StarCard({
    super.key,
    required this.info,
    required this.tables,
    required this.onTap,
    this.risingLine,
  });

  final DayInfo info;
  final Tables tables;
  final VoidCallback onTap;

  /// «طلع في الرياض قبل … يوماً» لسهيل والثريا، وإلا null.
  final String? risingLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    String name(String? id) => tables.items[id]?.name.ar ?? '';
    final ws = info.weatherSeason;
    return _TitledCard(
      key: HomeCardKeys.starCard,
      title: l10n.cardStarTitle,
      icon: CustomPaint(painter: _StarPainter(colors.goldText)),
      onTap: onTap,
      children: [
        Text(
          name(info.star.itemId),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.goldText,
          ),
        ),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.season(info.majorSeason.itemId),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.homeSeasonLabel(name(info.majorSeason.itemId)),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        Text(
          l10n.homeWeatherSeasonLabel(
            ws == null ? l10n.homeNone : name(ws.itemId),
          ),
          style: theme.textTheme.bodySmall,
        ),
        if (risingLine != null)
          Text(
            risingLine!,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.goldText),
          ),
      ],
    );
  }
}

/// بطاقة «الجو المعتاد» (DESIGN R2.8): شرائح الجو (أيقونة ملونة + كلمة)،
/// والشريحة تفتح فقاعة الرمز؛ وسطر «حسب التراث، وليس توقعاً للطقس.».
/// باقي البطاقة ← صفحة الدَّرّ.
class UsualWeatherCard extends StatelessWidget {
  const UsualWeatherCard({
    super.key,
    required this.info,
    required this.onTap,
    required this.onSymbol,
  });

  final DayInfo info;
  final VoidCallback onTap;

  /// ضغطة شريحة: الرمز وموضعها على الشاشة لفقاعته.
  final void Function(WeatherSymbol symbol, Rect anchor) onSymbol;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _TitledCard(
      key: HomeCardKeys.weatherCard,
      title: l10n.cardWeatherTitle,
      onTap: onTap,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: [
            for (final s in info.weather)
              _WeatherBubbleChip(
                key: HomeCardKeys.weatherChip(s),
                symbol: s,
                onTap: onSymbol,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.cardWeatherNote, style: theme.textTheme.bodySmall),
      ],
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
                  WeatherIcon(symbol, color: colors.weatherTone(symbol.code)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      weatherSymbolLabel(l10n, symbol),
                      style: Theme.of(context).textTheme.labelLarge,
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

/// شريط الدَّرّ بعرض كامل (DESIGN R2.8 بند 7): «دَرّ الستين» + شريحة «من
/// الصفري»؛ للمستعيرة «حسب حساب الإمارات وعُمان» والسطر الثابت من البيانات
/// (D24)؛ شريط التقدم بلون المئة؛ «اليوم ٨ من ١٠». الضغط ← صفحة الدَّرّ،
/// والشريحة ← صفحة موسم المئة.
class DarStrip extends StatelessWidget {
  const DarStrip({
    super.key,
    required this.info,
    required this.tables,
    required this.digits,
    required this.onTap,
    required this.onSeason,
  });

  final DayInfo info;
  final Tables tables;
  final DigitStyle digits;
  final VoidCallback onTap;
  final VoidCallback onSeason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final hundred = info.dar.record.seasonId;
    final tone = colors.season(hundred);
    final note = info.borrowsDurur
        ? tables.regionTables[info.regionId]?.dururBorrow?.note.ar
        : null;
    return GlassSurface(
      key: HomeCardKeys.darStrip,
      blur: true,
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
                l10n.darTitle(info.dar.name.ar),
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
          if (info.borrowsDurur)
            Text(
              l10n.darBorrowedCaption(
                tables.region(info.dururRegionId)?.name.ar ?? '',
              ),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 10),
          _DarProgress(info: info, color: tone),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  dayOfDarLabel(l10n, info, digits: digits),
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
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note,
              key: HomeCardKeys.borrowNote,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// شريط التقدم في الدَّرّ: مقطع لكل يوم بطوله الفعلي، يملأ من البداية
/// (اليمين في RTL)، واليوم الحالي بنقطة gold فوقه (DESIGN 5.6).
class _DarProgress extends StatelessWidget {
  const _DarProgress({required this.info, required this.color});

  final DayInfo info;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    final total = info.dar.length;
    final day = info.dar.dayNumber;
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
  const AgriCard({super.key, required this.onKnowSource});

  final VoidCallback onKnowSource;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    return _TitledCard(
      key: HomeCardKeys.agriCard,
      title: l10n.cardAgriTitle,
      icon: CustomPaint(painter: _SproutPainter(colors.agri)),
      children: [
        Text(l10n.agriNoData, style: theme.textTheme.bodyMedium),
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

/// بطاقة «القادم» (DESIGN R2.8): حتى 3 صفوف 48dp مرتبة بالأقرب: الاسم +
/// «بعد ٣ أيام». الصف ← صفحة العنصر.
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
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    return _TitledCard(
      key: HomeCardKeys.upcomingCard,
      title: l10n.cardUpcomingTitle,
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
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    seasonEventName(l10n, tables, e),
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    l10n.upcomingAfter(e.days, formatInteger(e.days, digits)),
                    style: theme.textTheme.bodySmall,
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
