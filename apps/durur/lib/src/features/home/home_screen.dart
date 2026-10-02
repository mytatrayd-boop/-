import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/day_info.dart';
import '../../domain/local_date.dart';
import '../../domain/tables.dart';
import '../../engine/year_index.dart';
import '../item_detail/detail_data.dart';
import '../item_detail/item_detail_sheet.dart';
import '../../providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_theme.dart';
import 'city_chip.dart';
import 'day_card.dart';
import '../common/load_error.dart';
import 'day_text.dart';
import 'dial/day_dial.dart';
import 'dial/dial_model.dart';
import 'dial/dial_painter.dart';

/// الشاشة الرئيسية (SPEC الميزة 6، DESIGN 8.4): سطر التاريخين، الدائرة،
/// صف التنقل، بطاقة اليوم، العبارة الثابتة، والمصدر.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const datesLineKey = Key('homeDatesLine');
  static const todayButtonKey = Key('homeTodayButton');
  static const prevKey = Key('homePrevDay');
  static const nextKey = Key('homeNextDay');
  static const pickDateKey = Key('homePickDate');
  static const skeletonKey = Key('homeSkeleton');
  static const loadErrorKey = Key('homeLoadError');
  static const calcErrorKey = Key('homeCalcError');
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
    final tables = ref.watch(tablesProvider);

    return Scaffold(
      appBar: AppBar(
        // DESIGN 8.4: شريحة المدينة في البداية (يمين)، والإعدادات في النهاية.
        title: const CityChip(),
        actions: [
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: switch (tables) {
        AsyncData(:final value) => _content(context, value),
        AsyncError() => DataLoadError(
          key: HomeScreen.loadErrorKey,
          onRetry: () => ref.invalidate(tablesProvider),
        ),
        _ => const _DelayedSkeleton(),
      },
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
    final isToday = selected == today;
    final digits = ref.watch(digitStyleProvider);

    if (info == null || index == null) {
      return _CalcError(message: l10n.homeCalcError);
    }

    final model = _modelFor(index);

    // من الدائرة: ورقة سفلية؛ من البطاقة: صفحة كاملة (DESIGN 8.4 و8.6).
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
        padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
        // ارتفاع ثابت للسطر بالصيغتين («تعرض:» أطول وقد تنكسر)، حتى لا تتحرك
        // الدائرة تحت الإصبع أثناء التدوير.
        child: Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _DatesLineText(
                lines: datesLines(
                  l10n,
                  selected,
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
      return other == null ? null : dialSemanticsValue(l10n, other, tables, digits: digits);
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
      semanticsValue: dialSemanticsValue(
        l10n,
        info,
        tables,
        digits: digits,
      ),
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
                padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : null;

    final nav = _NavRow(
      isToday: isToday,
      onPrev: () => controller.shiftDays(-1),
      onNext: () => controller.shiftDays(1),
      onPrevDar: () => controller.select(_prevDarStart(info)),
      onNextDar: () => controller.select(addDays(_local(info.dar.end), 1)),
      onPick: () => _pickDate(context, selected),
      onToday: controller.backToToday,
    );

    final footer = <Widget>[
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: colors.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.traditionDisclaimer,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
      if (region != null) ...[
        const SizedBox(height: 8),
        Text(
          l10n.commonSource(region.source.title),
          style: theme.textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: 24),
    ];

    final card = DayCard(
      info: info,
      digits: digits,
      tables: tables,
      onOpen: openPage,
      onOpenOrigin: openOrigin,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final density = screenWidth >= 400
            ? DialDensity.full
            : screenWidth >= 360
            ? DialDensity.medium
            : DialDensity.compact;
        final side = width >= 400 ? 20.0 : 16.0;

        // أفقي/تابلت: الدائرة على اليمين (البداية) والبطاقة بجانبها (DESIGN 7.6).
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
                    children: [
                      dialFor(diameter, DialDensity.full),
                      ?legend,
                      nav,
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: side),
                  children: [dates, card, ...footer],
                ),
              ),
            ],
          );
        }

        final scale = MediaQuery.textScalerOf(context).scale(1);
        // القطر حسب DESIGN 7.6، ولا يتجاوز العرض بعد هامشي الشاشة.
        final available = width - 2 * side;
        final double diameter;
        if (scale >= 1.5) {
          // تكبير الخط: تصغر الدائرة إلى 75% من العرض.
          diameter = math.min(screenWidth * 0.75, available);
        } else if (screenWidth >= 400) {
          diameter = math.min(360, available);
        } else {
          diameter = math.min(available, screenWidth >= 360 ? 400 : 288);
        }

        return ListView(
          padding: EdgeInsetsDirectional.symmetric(horizontal: side),
          children: [
            dates,
            Center(child: dialFor(diameter, density)),
            ?legend,
            nav,
            const SizedBox(height: 8),
            card,
            ...footer,
          ],
        );
      },
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

/// صف التنقل تحت الدائرة (DESIGN 7.5): السابق، اختر تاريخاً، التالي،
/// وزر «اليوم» فوقه عند عرض تاريخ آخر. الضغط المطوّل على السابق/التالي دَرّ.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPrevDar,
    required this.onNextDar,
    required this.onPick,
    required this.onToday,
  });

  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPrevDar;
  final VoidCallback onNextDar;
  final VoidCallback onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DururColors.of(context);
    return Column(
      children: [
        if (!isToday)
          FilledButton.icon(
            key: HomeScreen.todayButtonKey,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: const StadiumBorder(),
            ),
            onPressed: onToday,
            icon: Icon(Icons.circle, size: 10, color: colors.goldDeco),
            label: Text(l10n.commonToday),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavButton(
              key: HomeScreen.prevKey,
              label: l10n.homePrevDay,
              // السابق يشير للبداية (اليمين في RTL)؛ الأيقونة تنعكس تلقائياً.
              icon: Icons.chevron_left,
              onTap: onPrev,
              onLongPress: onPrevDar,
            ),
            _NavButton(
              key: HomeScreen.pickDateKey,
              label: l10n.homePickDate,
              icon: Icons.calendar_month_outlined,
              onTap: onPick,
            ),
            _NavButton(
              key: HomeScreen.nextKey,
              label: l10n.homeNextDay,
              icon: Icons.chevron_right,
              onTap: onNext,
              onLongPress: onNextDar,
            ),
          ],
        ),
      ],
    );
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

/// زر أيقونة 48dp بوصف لقارئ الشاشة، وضغطة مطوّلة اختيارية (DESIGN 7.5).
class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: 24,
        child: SizedBox.square(dimension: 48, child: Icon(icon)),
      ),
    );
  }
}

/// هيكل رمادي إن تأخر التحميل أكثر من 300ms، بلا وميض قبلها (DESIGN 8.4).
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
    final diameter = (width - 32).clamp(200.0, 360.0);
    Widget bar(double w) => Container(
      height: 16,
      width: w,
      margin: const EdgeInsetsDirectional.only(top: 12),
      decoration: BoxDecoration(
        color: colors.line,
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
              painter: _SkeletonPainter(colors.line),
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
      ..strokeWidth = 1.5;
    for (final f in const [
      1.0,
      146 / 170,
      130 / 170,
      102 / 170,
      78 / 170,
      60 / 170,
    ]) {
      canvas.drawCircle(size.center(Offset.zero), r * f - 1, paint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => old.color != color;
}

/// المحرك لم يجد نتيجة (يجب ألا يحدث بعد الاختبار، DESIGN 8.4).
class _CalcError extends StatelessWidget {
  const _CalcError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: HomeScreen.calcErrorKey,
      padding: const EdgeInsetsDirectional.all(24),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}
