import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/day_info.dart';
import '../../domain/item.dart';
import '../../domain/local_date.dart';
import '../../domain/tables.dart';
import '../../engine/year_index.dart';
import '../../formatting/date_labels.dart';
import '../../formatting/digits.dart';
import '../../notifications/notification_planner.dart' show heliacalDateOf;
import '../common/glass.dart';
import '../common/load_error.dart';
import '../item_detail/detail_data.dart';
import '../item_detail/item_detail_sheet.dart';
import '../report/report_sheet.dart';
import '../../providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_theme.dart';
import 'city_chip.dart';
import 'day_text.dart';
import 'dial/day_dial.dart';
import 'dial/dial_model.dart';
import 'dial/dial_painter.dart';
import 'home_cards.dart';
import 'season_events.dart';
import 'symbol_bubble.dart';

/// الشاشة الرئيسية (SPEC الميزة 6، DESIGN R2.8): الشريط العلوي، سطر
/// التاريخين، الدائرة، صف العدّاد، بطاقتا الطالع والجو المعتاد، شريط الدَّرّ،
/// بطاقتا الزراعة والقادم، العبارة الثابتة والمصدر. فوق خلفية سماء الليل.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const datesLineKey = Key('homeDatesLine');
  static const todayButtonKey = Key('homeTodayButton');
  static const prevKey = Key('homePrevDay');
  static const nextKey = Key('homeNextDay');
  static const skeletonKey = Key('homeSkeleton');
  static const loadErrorKey = Key('homeLoadError');
  static const calcErrorKey = Key('homeCalcError');
  static const calcErrorReportKey = Key('homeCalcErrorReport');
  static const legendKey = Key('dialDururLegend');

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    // العودة للتطبيق في يوم جديد تحدّث «اليوم» (DESIGN 8.4).
    onResume: () => ref.read(todayProvider.notifier).refresh(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tables = ref.watch(tablesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: NightSky()),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // DESIGN R2.8 بند 1: «دليل المواسم» Amiri 21 في البداية (يمين)،
                // وشريحة المدينة الزجاجية في النهاية. الإعدادات صارت تبويباً
                // (R2.9). مع تكبير الخط يلتف العنوان بدل أن يفيض.
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              l10n.appTitle,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(child: CityChip()),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: switch (tables) {
                    // أثناء إعادة التحميل بعد تحديث البيانات (§16.5) تبقى
                    // الجداول السابقة معروضة حتى تكتمل الجديدة، بلا وميض.
                    AsyncValue(hasError: false, :final value?) => _content(
                      context,
                      value,
                    ),
                    AsyncError() => DataLoadError(
                      key: HomeScreen.loadErrorKey,
                      onRetry: () => ref.invalidate(tablesProvider),
                    ),
                    _ => const _DelayedSkeleton(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, Tables tables) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final today = ref.watch(todayProvider);
    final selected = ref.watch(selectedDateProvider);
    final info = ref.watch(dayInfoProvider(selected));
    final index = ref.watch(yearIndexProvider(selected.year));
    final region = ref.watch(currentRegionProvider);
    final city = ref.watch(currentCityProvider);
    final isToday = selected == today;
    final digits = ref.watch(digitStyleProvider);

    if (info == null || index == null) {
      return _CalcError(
        message: l10n.homeCalcError,
        onReport: () => showReportSheet(
          context,
          regionName: region?.name.ar,
          date: selected,
        ),
      );
    }

    final model = _modelFor(index);

    // من الدائرة: ورقة سفلية؛ من البطاقات: صفحة كاملة (DESIGN 8.4 و8.6).
    void open(DialRing ring, DayInfo day) =>
        showItemDetailSheet(context, detailRequestFor(ring, day));
    void openPage(DialRing ring, DayInfo day) {
      final r = detailRequestFor(ring, day);
      context.push(AppRoutes.detail(r.target, from: r.from));
    }

    void openOrigin() => context.push(AppRoutes.origin);
    final controller = ref.read(selectedDateProvider.notifier);

    final dates = InkWell(
      key: HomeScreen.datesLineKey,
      onTap: () => _pickDate(context, selected),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 8,
          horizontal: 16,
        ),
        // ارتفاع ثابت للسطر بالصيغتين («تعرض:» أطول وقد تنكسر) ولأطول تاريخ
        // (الأربعاء ١٧ ديسمبر — ٢٦ جمادى الآخرة)، حتى لا تتحرك الدائرة تحت
        // الإصبع أثناء التدوير.
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final reference in [selected, DateTime(2025, 12, 17)])
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: _DatesLineText(
                  lines: datesLines(
                    l10n,
                    reference,
                    tables.hijri,
                    isToday: false,
                    digits: digits,
                  ),
                  style: theme.textTheme.bodyMedium!,
                ),
              ),
            _DatesLineText(
              lines: datesLines(
                l10n,
                selected,
                tables.hijri,
                isToday: isToday,
                digits: digits,
              ),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: isToday ? colors.inkSoft : colors.goldText,
              ),
            ),
          ],
        ),
      ),
    );

    // قيمة قارئ الشاشة لليوم التالي والسابق (عبر نهاية السنة)، وnull خارج
    // 2025–2040.
    String? neighbourValue(int days) {
      final day = addDays(selected, days);
      if (day.isBefore(DateRange.first) || day.isAfter(DateRange.last)) {
        return null;
      }
      final other = ref.watch(dayInfoProvider(day));
      return other == null
          ? null
          : dialSemanticsValue(l10n, other, tables, digits: digits);
    }

    Widget dialFor(double diameter, DialDensity density) => DayDial(
      diameter: diameter,
      digits: digits,
      density: density,
      model: model,
      tables: tables,
      selected: selected,
      today: today,
      semanticsLabel: dialSemanticsPrefix(l10n, isToday: isToday),
      semanticsValue: dialSemanticsValue(l10n, info, tables, digits: digits),
      increasedValue: neighbourValue(1),
      decreasedValue: neighbourValue(-1),
      onSelect: controller.select,
      onShift: controller.shiftDays,
      onOpen: open,
      onBackToToday: controller.backToToday,
    );

    // سطر الإيضاح للمنطقة المستعيرة (DESIGN 7.8): الضغط عليه (منطقة لمس
    // 48dp) يفتح صفحة «أصل التقويم».
    final legend = info.borrowsDurur
        ? InkWell(
            key: HomeScreen.legendKey,
            onTap: openOrigin,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: colors.inkSoft),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.dialDururLegend(
                          tables.region(info.dururRegionId)?.name.ar ?? '',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : null;

    // ———— العدّاد والقادم (R2.8) ————
    final events = seasonEvents(
      from: selected,
      resolve: _resolver,
      items: tables.items,
      rising: (id, year) =>
          heliacalDateOf(id, ref.watch(currentHeliacalProvider(year))),
    );
    final countdown = countdownEvent(events);
    final upcoming = upcomingEvents(events, countdown);

    void openEvent(SeasonEvent e) {
      if (e.kind == SeasonEventKind.dar) {
        final day = ref.read(dayInfoProvider(e.date));
        if (day != null) openPage(DialRing.durur, day);
        return;
      }
      context.push(AppRoutes.item(e.itemId!, from: e.date));
    }

    final scale = MediaQuery.textScalerOf(context).scale(1);
    final bigText = scale >= 1.5;

    final prev = GlassCircleButton(
      key: HomeScreen.prevKey,
      label: l10n.homePrevDay,
      // السابق يشير للبداية (اليمين في RTL، DESIGN 7.5).
      glyph: '›',
      onTap: () => controller.shiftDays(-1),
      onLongPress: () => controller.select(_prevDarStart(info)),
    );
    final next = GlassCircleButton(
      key: HomeScreen.nextKey,
      label: l10n.homeNextDay,
      glyph: '‹',
      onTap: () => controller.shiftDays(1),
      onLongPress: () =>
          controller.select(addDays(_local(info.dar.end), 1)),
    );
    final counter = countdown == null
        ? const SizedBox(height: 48)
        : CountdownCard(
            event: countdown,
            tables: tables,
            digits: digits,
            cityName: city?.name.ar,
            viewing: isToday ? null : selected,
            onTap: () => openEvent(countdown),
          );
    final countdownRow = Column(
      children: [
        if (!isToday)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: FilledButton.icon(
              key: HomeScreen.todayButtonKey,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: controller.backToToday,
              icon: Icon(Icons.circle, size: 10, color: colors.onPrimary),
              label: Text(l10n.commonToday),
            ),
          ),
        // تكبير خط ≥ 1.5×: العدّاد بعرض كامل والزران تحته (R2.10).
        if (bigText) ...[
          counter,
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [prev, next],
          ),
        ] else
          Row(
            children: [
              prev,
              const SizedBox(width: 12),
              Expanded(child: counter),
              const SizedBox(width: 12),
              next,
            ],
          ),
      ],
    );

    String? risingLine() {
      final item = tables.items[info.star.itemId];
      if (item == null || item.dateMethod != DateMethod.heliacal) return null;
      final utc = heliacalDateOf(
        item.id,
        ref.watch(currentHeliacalProvider(selected.year)),
      );
      if (city == null || utc == null) return null;
      final rising = DateTime(utc.year, utc.month, utc.day);
      final gender = item.gender.code;
      if (rising == selected) {
        return l10n.detailStarRisesToday(gender, city.name.ar);
      }
      if (rising.isAfter(selected)) {
        return l10n.detailStarRisesOn(
          gender,
          city.name.ar,
          gregorianDateLabel(l10n, rising, digits: digits),
        );
      }
      final days = daysBetween(rising, selected);
      return l10n.detailStarRisenAgo(
        gender,
        days,
        city.name.ar,
        formatInteger(days, digits),
      );
    }

    final starCard = StarCard(
      info: info,
      tables: tables,
      risingLine: risingLine(),
      onTap: () => openPage(DialRing.stars, info),
    );
    final weatherCard = UsualWeatherCard(
      info: info,
      onTap: () => openPage(DialRing.durur, info),
      onSymbol: (symbol, anchor) => showSymbolBubble(
        context,
        anchor: anchor,
        symbol: symbol,
        period: _darPeriodText(l10n, info, digits),
      ),
    );
    final darStrip = DarStrip(
      info: info,
      tables: tables,
      digits: digits,
      onTap: () => openPage(DialRing.durur, info),
      onSeason: () => context.push(
        AppRoutes.item(info.dar.record.seasonId, from: selected),
      ),
    );
    final agriCard = AgriCard(
      onKnowSource: () => showReportSheet(
        context,
        regionName: region?.name.ar,
        date: selected,
      ),
    );
    final upcomingCard = upcoming.isEmpty
        ? null
        : UpcomingCard(
            events: upcoming,
            tables: tables,
            digits: digits,
            onOpen: openEvent,
          );

    Widget pair(Widget a, Widget? b) => bigText || b == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [a, if (b != null) ...[const SizedBox(height: 12), b]],
          )
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: a),
                const SizedBox(width: 12),
                Expanded(child: b),
              ],
            ),
          );

    final footer = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.traditionDisclaimer,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (region != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.commonSource(region.source.title),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );

    final below = <Widget>[
      ?legend,
      const SizedBox(height: 4),
      countdownRow,
      const SizedBox(height: 12),
      pair(starCard, weatherCard),
      const SizedBox(height: 12),
      darStrip,
      const SizedBox(height: 12),
      pair(agriCard, upcomingCard),
      footer,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final density = screenWidth >= 400
            ? DialDensity.full
            : screenWidth >= 360
            ? DialDensity.medium
            : DialDensity.compact;
        const side = 16.0;

        // أفقي/تابلت: الدائرة على اليمين (البداية) والبطاقات بجانبها (7.6).
        if (width >= 600 && width > constraints.maxHeight) {
          final diameter = (constraints.maxHeight - 140)
              .clamp(200.0, 480.0)
              .clamp(200.0, width / 2 - 2 * side);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: diameter + 2 * side,
                child: SingleChildScrollView(
                  child: Column(
                    children: [dates, dialFor(diameter, DialDensity.full)],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    side,
                    8,
                    side,
                    16,
                  ),
                  children: below,
                ),
              ),
            ],
          );
        }

        // القطر = عرض الشاشة − 28 (هامش 14 لرأس المؤشر والتوهج)، حد أقصى
        // 480 (R2.5)؛ ومع تكبير الخط ≥ 1.5× تصغر إلى 75% من العرض (7.6).
        final double diameter = bigText
            ? math.min(screenWidth * 0.75, width - 28)
            : math.min(480, width - 28);

        return ListView(
          children: [
            dates,
            Center(child: dialFor(diameter, density)),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: side),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: below,
              ),
            ),
          ],
        );
      },
    );
  }

  /// نتيجة المحرك ليوم من فهرس سنته المخزّن (للعدّاد و«القادم»).
  DayInfo? _resolver(DateTime day) {
    final index = ref.read(yearIndexProvider(day.year));
    if (index == null) return null;
    final i = daysBetween(DateTime(day.year), day);
    return i >= 0 && i < index.days.length ? index.days[i] : null;
  }

  /// سطر الفترة لفقاعة شريحة الجو: الدَّرّ الحالي ومداه.
  String _darPeriodText(
    AppLocalizations l10n,
    DayInfo info,
    DigitStyle digits,
  ) {
    String dm(DateTime d) =>
        l10n.dayMonthDate(formatInteger(d.day, digits), 'g${d.month}');
    return l10n.bubblePeriod(
      l10n.bubbleRange(
        l10n.darTitle(info.dar.name.ar),
        dm(info.dar.start),
        dm(info.dar.end),
      ),
    );
  }

  // نموذج الدائرة مخزّن لكل سنة/منطقة (لا يُعاد بناؤه مع كل يوم).
  DialModel? _model;

  DialModel _modelFor(YearIndex index) {
    if (_model?.index != index) _model = DialModel.fromYearIndex(index);
    return _model!;
  }

  static DateTime _local(DateTime utc) =>
      DateTime(utc.year, utc.month, utc.day);

  DateTime _prevDarStart(DayInfo info) {
    final before = ref.read(
      dayInfoProvider(addDays(_local(info.dar.start), -1)),
    );
    return before == null
        ? addDays(_local(info.dar.start), -1)
        : _local(before.dar.start);
  }

  Future<void> _pickDate(BuildContext context, DateTime selected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateRange.first,
      lastDate: DateRange.last,
      helpText: AppLocalizations.of(context).homePickDate,
    );
    if (picked != null) ref.read(selectedDateProvider.notifier).select(picked);
  }
}

/// سطر التاريخين: سطر واحد بفاصل «—» إن اتسع، وإلا سطران بلا فاصل
/// (DESIGN 8.4).
class _DatesLineText extends StatelessWidget {
  const _DatesLineText({required this.lines, required this.style});

  final DatesLine lines;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: lines.single, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        painter.dispose();
        final second = lines.second;
        return Text(
          fits || second == null ? lines.single : '${lines.first}\n$second',
          textAlign: TextAlign.center,
          style: style,
        );
      },
    );
  }
}

/// هيكل زجاجي فارغ إن تأخر التحميل أكثر من 300ms، بلا وميض قبلها (R2.8).
class _DelayedSkeleton extends StatefulWidget {
  const _DelayedSkeleton();

  @override
  State<_DelayedSkeleton> createState() => _DelayedSkeletonState();
}

class _DelayedSkeletonState extends State<_DelayedSkeleton> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _visible = true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.expand();
    final colors = DururColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final diameter = (width - 28).clamp(200.0, 480.0);
    Widget bar(double w) => Container(
      height: 16,
      width: w,
      margin: const EdgeInsetsDirectional.only(top: 12),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return ExcludeSemantics(
      key: HomeScreen.skeletonKey,
      child: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Center(
            child: CustomPaint(
              size: Size.square(diameter),
              painter: _SkeletonPainter(colors.glassStroke),
            ),
          ),
          bar(width * 0.5),
          bar(width * 0.8),
          bar(width * 0.6),
        ],
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  const _SkeletonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fractions = {
      for (final (o, i) in DialGeometry.bands.values) ...[o, i],
    };
    for (final f in fractions) {
      canvas.drawCircle(size.center(Offset.zero), r * f - 1, paint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => old.color != color;
}

/// المحرك لم يجد نتيجة (يجب ألا يحدث بعد الاختبار): «تعذّر حساب هذا اليوم.»
/// + زر «أبلغ عن خطأ» (DESIGN 8.4، R2.8 الخطأ).
class _CalcError extends StatelessWidget {
  const _CalcError({required this.message, required this.onReport});

  final String message;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: HomeScreen.calcErrorKey,
      padding: const EdgeInsetsDirectional.all(24),
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(
          key: HomeScreen.calcErrorReportKey,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: onReport,
          child: Text(AppLocalizations.of(context).reportTitle),
        ),
      ],
    );
  }
}
