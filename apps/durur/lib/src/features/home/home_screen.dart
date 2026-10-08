import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../astronomy/seasons.dart';
import '../../domain/day_info.dart';
import '../../domain/item.dart';
import '../../domain/local_date.dart';
import '../../domain/tables.dart';
import '../../engine/year_index.dart';
import '../../formatting/date_labels.dart';
import '../../formatting/digits.dart';
import '../../notifications/notification_planner.dart' show heliacalDateOf;
import '../common/glass.dart';
import '../common/gulf_backdrop.dart';
import '../common/load_error.dart';
import '../item_detail/detail_data.dart';
import '../item_detail/item_detail_sheet.dart';
import '../report/report_sheet.dart';
import '../../providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_theme.dart';
import 'astro_sheets.dart';
import 'day_text.dart';
import 'dial/day_dial.dart';
import 'dial/dial_model.dart';
import 'dial/dial_painter.dart';
import 'home_cards.dart';
import 'season_events.dart';
import 'symbol_bubble.dart';

/// الشاشة الرئيسية (SPEC الميزة 6، DESIGN R3.1): الصف العلوي (القائمة،
/// العنوان وسطر المكان والتاريخ، الجرس)، الدائرة، العدّاد، البطاقات الأربع
/// بعمودين، شريط الدَّرّ (أو «الجو المعتاد» بلا درور)، العبارة الثابتة
/// والمصدر. فوق خلفية تركوازية وخريطة الخليج ووردة الرياح.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const datesLineKey = Key('homeDatesLine');
  static const placeKey = Key('homePlace');
  static const menuKey = Key('homeMenu');
  static const bellKey = Key('homeBell');
  static const drawerKey = Key('homeDrawer');
  static const todayButtonKey = Key('homeTodayButton');
  static const prevKey = Key('homePrevDay');
  static const nextKey = Key('homeNextDay');
  static const skeletonKey = Key('homeSkeleton');
  static const loadErrorKey = Key('homeLoadError');
  static const calcErrorKey = Key('homeCalcError');
  static const calcErrorReportKey = Key('homeCalcErrorReport');
  static Key drawerItem(int i) => Key('homeDrawerItem$i');

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
    final tables = ref.watch(tablesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const _HomeDrawer(),
      body: Stack(
        children: [
          const Positioned.fill(child: NightSky(glowCenter: 0.28)),
          SafeArea(
            bottom: false,
            child: switch (tables) {
              // أثناء إعادة التحميل بعد تحديث البيانات (§16.5) تبقى الجداول
              // السابقة معروضة حتى تكتمل الجديدة، بلا وميض.
              AsyncValue(hasError: false, :final value?) => _content(
                context,
                value,
              ),
              AsyncError() => Column(
                children: [
                  _header(context, null),
                  Expanded(
                    child: DataLoadError(
                      key: HomeScreen.loadErrorKey,
                      onRetry: () => ref.invalidate(tablesProvider),
                    ),
                  ),
                ],
              ),
              _ => Column(
                children: [
                  _header(context, null),
                  const Expanded(child: _DelayedSkeleton()),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }

  /// الصف العلوي 60dp (R3.1-1): القائمة في البداية (يمين)، والعنوان في
  /// الوسط وتحته سطر المكان والتاريخ، والجرس في النهاية (يسار).
  Widget _header(BuildContext context, Tables? tables) {
    final l10n = AppLocalizations.of(context);
    final colors = DururColors.of(context);
    final city = ref.watch(currentCityProvider);
    final selected = ref.watch(selectedDateProvider);
    final today = ref.watch(todayProvider);
    final digits = ref.watch(digitStyleProvider);
    final denied = ref.watch(notificationPermissionProvider).value == false;
    final hijri = tables?.hijri?.tryConvert(selected);
    final dateText = hijri == null
        ? gregorianDateLabel(l10n, selected, digits: digits)
        : hijriDateLabel(l10n, hijri, digits: digits);
    final lineStyle = TextStyle(
      fontFamily: DururFonts.body,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: selected == today ? colors.inkSoft : colors.goldText,
    );
    Widget touch({
      required Key key,
      required String label,
      required VoidCallback onTap,
      required Widget child,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    );

    final placeName = city?.name.ar ?? l10n.cityPickerTitle;
    final line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: touch(
            key: HomeScreen.placeKey,
            label: placeName,
            onTap: () => context.push(AppRoutes.city),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined, size: 12, color: colors.primary),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: lineStyle.copyWith(color: colors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        ),
        ExcludeSemantics(child: Text(l10n.headerSeparator, style: lineStyle)),
        Flexible(
          child: touch(
            key: HomeScreen.datesLineKey,
            label: [
              if (selected != today)
                l10n.homeViewingDate(dateText)
              else
                dateText,
              l10n.homePickDate,
            ].join(l10n.listSeparator),
            onTap: () => _pickDate(context, selected),
            child: Text(
              selected == today ? dateText : l10n.homeViewingDate(dateText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: lineStyle,
            ),
          ),
        ),
      ],
    );

    final icon = colors.ink;
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          // السطر بمناطق لمس 48dp تتداخل مع العنوان فوقها (لا تحته، حتى لا
          // تغطيها الدائرة في ترتيب اللمس).
          PositionedDirectional(
            start: 56,
            end: 56,
            bottom: 0,
            height: 48,
            child: Center(child: line),
          ),
          PositionedDirectional(
            start: 56,
            end: 56,
            top: 2,
            child: IgnorePointer(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.appTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DururFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: colors.ink,
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 8,
            top: 6,
            child: Builder(
              builder: (context) => IconButton(
                key: HomeScreen.menuKey,
                tooltip: l10n.headerMenu,
                iconSize: 24,
                icon: Icon(Icons.menu, color: icon),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          PositionedDirectional(
            end: 8,
            top: 6,
            child: IconButton(
              key: HomeScreen.bellKey,
              tooltip: denied
                  ? l10n.headerNotificationsDenied
                  : l10n.headerNotifications,
              iconSize: 24,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_none, color: icon),
                  if (denied)
                    PositionedDirectional(
                      top: 1,
                      end: 1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => context.go(AppRoutes.settings),
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
    final header = _header(context, tables);

    // فشل الحساب الفلكي يعيد بديلاً (astro.computed = false): الدائرة بالصليب
    // بلا تواريخ، و«تعذّر حساب هذا اليوم.» مكان البطاقات (R3.4، SPEC 19.10).
    final astro = ref.watch(astroYearProvider(selected.year));
    if (info == null || index == null) {
      return _withHeader(
        header,
        _calcError(context, region?.name.ar, selected),
      );
    }

    final model = _modelFor(index, astro, tables);
    final hasDurur = model.hasDurur;
    final dar = info.dar;

    // من الدائرة: ورقة سفلية؛ من البطاقات: صفحة كاملة (DESIGN 8.4 و8.6).
    void open(DialRing ring, DayInfo day) {
      final local = DateTime(day.date.year, day.date.month, day.date.day);
      final dayAstro = ref.read(astroYearProvider(local.year));
      if (!dayAstro.computed &&
          (ring == DialRing.seasons || ring == DialRing.zodiac)) {
        return;
      }
      switch (ring) {
        case DialRing.seasons:
          showAstroSeasonSheet(
            context,
            period: dayAstro.seasonAt(local),
            selected: selected,
            today: today,
            resolve: (d) => ref.read(dayInfoProvider(dateOnly(d))),
            tables: tables,
            digits: digits,
          );
        case DialRing.zodiac:
          showZodiacSheet(
            context,
            period: dayAstro.zodiacAt(local),
            digits: digits,
          );
        default:
          showItemDetailSheet(context, detailRequestFor(ring, day));
      }
    }

    void openPage(DialRing ring, DayInfo day) {
      final r = detailRequestFor(ring, day);
      context.push(AppRoutes.detail(r.target, from: r.from));
    }

    final controller = ref.read(selectedDateProvider.notifier);

    // جملة الفصل لقارئ الشاشة (R3.5).
    String? astroSentence(DayInfo day) {
      final local = DateTime(day.date.year, day.date.month, day.date.day);
      final y = ref.read(astroYearProvider(local.year));
      if (!y.computed) return null;
      final p = y.seasonAt(local);
      String dm(DateTime d) =>
          l10n.dayMonthDate(formatInteger(d.day, digits), 'g${d.month}');
      return l10n.astroSeasonA11ySentence(
        l10n.astroSeasonName(p.value.name),
        dm(p.start.day),
        dm(p.end.day),
      );
    }

    String valueFor(DayInfo day) => dialSemanticsValue(
      l10n,
      day,
      tables,
      digits: digits,
      astroSentence: astroSentence(day),
    );

    // قيمة قارئ الشاشة لليوم التالي والسابق، وnull خارج 2025–2040.
    String? neighbourValue(int days) {
      final day = addDays(selected, days);
      if (day.isBefore(DateRange.first) || day.isAfter(DateRange.last)) {
        return null;
      }
      final other = ref.watch(dayInfoProvider(day));
      return other == null ? null : valueFor(other);
    }

    String readSeasonZodiac(DayInfo day) {
      final local = DateTime(day.date.year, day.date.month, day.date.day);
      final y = ref.read(astroYearProvider(local.year));
      if (!y.computed) return l10n.homeCalcError;
      return [
        astroSentence(day),
        l10n.zodiacSunIn(l10n.zodiacName(y.zodiacAt(local).value.name)),
      ].join(' ');
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
      semanticsValue: valueFor(info),
      increasedValue: neighbourValue(1),
      decreasedValue: neighbourValue(-1),
      onSelect: controller.select,
      onShift: controller.shiftDays,
      onOpen: open,
      onBackToToday: controller.backToToday,
      onReadSeasonZodiac: readSeasonZodiac,
    );

    // ———— العدّاد والقادم ————
    final events = seasonEvents(
      from: selected,
      resolve: _resolver,
      items: tables.items,
      rising: (id, year) =>
          heliacalDateOf(id, ref.watch(currentHeliacalProvider(year))),
    );
    final countdown = countdownEvent(events);
    final upcoming = upcomingEvents(events, countdown, hasDurur: hasDurur);

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

    // الفترة التي يقفز إليها الضغط المطوّل: الدَّرّ، أو الطالع بلا درور.
    final ActivePeriod jump = dar ?? info.star;
    final prev = GlassCircleButton(
      key: HomeScreen.prevKey,
      label: l10n.homePrevDay,
      // السابق يشير للبداية (اليمين في RTL، DESIGN 7.5).
      glyph: '›',
      onTap: () => controller.shiftDays(-1),
      onLongPress: () => controller.select(_prevJumpStart(jump)),
    );
    final next = GlassCircleButton(
      key: HomeScreen.nextKey,
      label: l10n.homeNextDay,
      glyph: '‹',
      onTap: () => controller.shiftDays(1),
      onLongPress: () => controller.select(addDays(_local(jump.end), 1)),
    );
    final counter = countdown == null
        ? const SizedBox(height: 48, width: 200)
        : CountdownCard(
            event: countdown,
            tables: tables,
            digits: digits,
            cityName: city?.name.ar,
            viewing: isToday ? null : selected,
            onTap: () => openEvent(countdown),
          );
    final todayPill = isToday
        ? null
        : Padding(
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
          );
    // العدّاد 200dp في الوسط، والزران على بعد 8dp من جانبيه (R3.1-17).
    // تكبير خط ≥ 1.5×: العدّاد بعرض كامل والزران تحته (R2.10).
    final countdownRow = Column(
      children: [
        ?todayPill,
        if (bigText) ...[
          counter,
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [prev, next],
          ),
        ] else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              prev,
              const SizedBox(width: 2),
              // 200dp، ويضيق على الشاشات الأضيق من 332dp حتى يتسع الزران.
              Flexible(child: SizedBox(width: 200, child: counter)),
              const SizedBox(width: 2),
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

    // الطوالع الثلاثة التالية للخانات (R3.1-16).
    final starSegs = model.cyclicSegments(DialRing.stars);
    final currentStar = starSegs.indexWhere(
      (s) => s.itemId == info.star.itemId,
    );
    final nextStars = [
      for (var k = 1; k <= 3 && k < starSegs.length; k++)
        starSegs[(currentStar + k) % starSegs.length].itemId!,
    ];

    void onSymbol(symbol, Rect anchor) => showSymbolBubble(
      context,
      anchor: anchor,
      symbol: symbol,
      period: _periodText(l10n, info, tables, digits),
    );

    final starCard = StarCard(
      info: info,
      tables: tables,
      nextStars: nextStars,
      risingLine: risingLine(),
      onTap: () => openPage(DialRing.stars, info),
      onStar: (id) => context.push(AppRoutes.item(id, from: selected)),
    );
    const weatherCard = LiveWeatherCard();
    final agriCard = AgriCard(
      regionName: region?.name.ar,
      onKnowSource: () =>
          showReportSheet(context, regionName: region?.name.ar, date: selected),
    );
    final upcomingCard = UpcomingCard(
      events: upcoming,
      tables: tables,
      digits: digits,
      onOpen: openEvent,
    );
    final Widget darOrUsual = dar != null
        ? DarStrip(
            info: info,
            dar: dar,
            tables: tables,
            digits: digits,
            onTap: () => openPage(DialRing.durur, info),
            onSeason: () => context.push(
              AppRoutes.item(dar.record.seasonId, from: selected),
            ),
            onSymbol: onSymbol,
          )
        : UsualWeatherCard(
            info: info,
            onTap: () => openPage(DialRing.stars, info),
            onSymbol: onSymbol,
          );

    final astroFailed = !astro.computed;
    final astroError = _CalcError(
      inline: true,
      message: l10n.homeCalcError,
      onReport: () =>
          showReportSheet(context, regionName: region?.name.ar, date: selected),
    );

    // شبكة العمودين (R3.1-15): الصف 1 الزراعة (يمين) والطالع (يسار)، والصف
    // 2 القادم (يمين) والطقس (يسار). تكبير الخط ≥ 1.5×: عمود واحد.
    Widget pair(Widget a, Widget b) => bigText
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [a, const SizedBox(height: 12), b],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final density = screenWidth >= 400
            ? DialDensity.full
            : screenWidth >= 360
            ? DialDensity.medium
            : DialDensity.compact;
        const side = 16.0;

        // الجهاز اللوحي (≥ 600dp): مواضع المرجع (R3.0): الدائرة مركزها على
        // y 37.9%، والبطاقتان العلويتان فوق زاويتيها تنتهيان عند y 79.0%،
        // والسفليتان من y 80.1% والعدّاد بينهما. البطاقات تتمدد بمحتواها ولا
        // تُقص (R3.1-15): العلويتان تنموان لأعلى فوق زاوية الدائرة كالمرجع،
        // والسفليتان لأسفل.
        if (width >= 600 && !bigText) {
          final h = math.max(height, width * 1.2);
          final diameter = math.min(width * 0.96, h * 0.74);
          final cardWidth = width * 0.227;
          final cardSide = width * 0.024;
          Widget top(Widget child) => SizedBox(width: cardWidth, child: child);
          return SingleChildScrollView(
            child: Stack(
              children: [
                Positioned.fill(child: GulfBackdrop(firstScreenHeight: h)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: h * 0.801,
                      child: Stack(
                        children: [
                          // الدائرة تبدأ تحت الصف العلوي دائماً (R3.1-1 و2).
                          PositionedDirectional(
                            top: math.max(
                              64,
                              h * 0.379 - diameter / 2 - DayDial.margin,
                            ),
                            start: (width - diameter) / 2,
                            child: dialFor(diameter, DialDensity.full),
                          ),
                          PositionedDirectional(
                            top: 0,
                            start: 0,
                            end: 0,
                            child: header,
                          ),
                          // البداية (يمين): الزراعة؛ النهاية: الطالع.
                          if (!astroFailed) ...[
                            PositionedDirectional(
                              start: cardSide,
                              bottom: h * (0.801 - 0.790),
                              child: top(agriCard),
                            ),
                            PositionedDirectional(
                              end: cardSide,
                              bottom: h * (0.801 - 0.790),
                              child: top(starCard),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: cardSide,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: astroFailed ? null : upcomingCard,
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                top: h * (0.837 - 0.801),
                              ),
                              child: countdownRow,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: astroFailed ? null : weatherCard,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        side,
                        12,
                        side,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ?(astroFailed ? astroError : null),
                          darOrUsual,
                          footer,
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // الهاتف: القطر = العرض − 16 (حد أقصى 560، R3.1-2)؛ ومع تكبير الخط
        // ≥ 1.5× تصغر إلى 75% من العرض (7.6).
        final double diameter = bigText
            ? math.min(screenWidth * 0.75, width - 16)
            : math.min(560, width - 16);

        return SingleChildScrollView(
          child: Stack(
            children: [
              Positioned.fill(child: GulfBackdrop(firstScreenHeight: height)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 4),
                  Center(child: dialFor(diameter, density)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: side,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        countdownRow,
                        const SizedBox(height: 12),
                        if (astroFailed)
                          astroError
                        else ...[
                          pair(agriCard, starCard),
                          const SizedBox(height: 12),
                          pair(upcomingCard, weatherCard),
                        ],
                        const SizedBox(height: 12),
                        darOrUsual,
                        footer,
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _withHeader(Widget header, Widget body) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      header,
      Expanded(child: body),
    ],
  );

  Widget _calcError(BuildContext context, String? regionName, DateTime date) =>
      _CalcError(
        message: AppLocalizations.of(context).homeCalcError,
        onReport: () =>
            showReportSheet(context, regionName: regionName, date: date),
      );

  /// نتيجة المحرك ليوم من فهرس سنته المخزّن (للعدّاد و«القادم»).
  DayInfo? _resolver(DateTime day) {
    final index = ref.read(yearIndexProvider(day.year));
    if (index == null) return null;
    final i = daysBetween(DateTime(day.year), day);
    return i >= 0 && i < index.days.length ? index.days[i] : null;
  }

  /// سطر الفترة لفقاعة شريحة الجو: الدَّرّ الحالي ومداه، أو الطالع بلا درور.
  String _periodText(
    AppLocalizations l10n,
    DayInfo info,
    Tables tables,
    DigitStyle digits,
  ) {
    String dm(DateTime d) =>
        l10n.dayMonthDate(formatInteger(d.day, digits), 'g${d.month}');
    final dar = info.dar;
    final ActivePeriod period = dar ?? info.star;
    final name = dar != null
        ? l10n.darTitle(dar.name.ar)
        : l10n.wheelHubStar(tables.items[info.star.itemId]?.name.ar ?? '');
    return l10n.bubblePeriod(
      l10n.bubbleRange(name, dm(period.start), dm(period.end)),
    );
  }

  // نموذج الدائرة مخزّن لكل سنة/منطقة (لا يُعاد بناؤه مع كل يوم).
  DialModel? _model;

  DialModel _modelFor(YearIndex index, AstroYear astro, Tables tables) {
    if (_model?.index != index || _model?.astro != astro) {
      _model = DialModel.fromYearIndex(
        index,
        astro: astro,
        items: tables.items,
      );
    }
    return _model!;
  }

  static DateTime _local(DateTime utc) =>
      DateTime(utc.year, utc.month, utc.day);

  /// بداية الفترة السابقة (دَرّ، أو طالع بلا درور).
  DateTime _prevJumpStart(ActivePeriod period) {
    final before = ref.read(dayInfoProvider(addDays(_local(period.start), -1)));
    final ActivePeriod? prev = before == null
        ? null
        : (period is DarPeriod ? before.dar : before.star);
    return prev == null
        ? addDays(_local(period.start), -1)
        : _local(prev.start);
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

/// الدرج الجانبي من اليمين (R3.1-1): عرضه 304dp بسطح زجاجي، واختصارات إلى
/// شاشات موجودة: الموقع، والتنبيهات، والمصادر، وأصل التقويم، وأبلغ عن خطأ.
class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = DururColors.of(context);
    final region = ref.watch(currentRegionProvider);
    final selected = ref.watch(selectedDateProvider);
    void go(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    final items = <(IconData, String, VoidCallback)>[
      (
        Icons.place_outlined,
        l10n.settingsCity,
        () => go(() => context.push(AppRoutes.city)),
      ),
      (
        Icons.notifications_none,
        l10n.settingsSectionNotifications,
        () => go(() => context.go(AppRoutes.settings)),
      ),
      (
        Icons.menu_book_outlined,
        l10n.settingsSources,
        () => go(() => context.push(AppRoutes.sources)),
      ),
      (
        Icons.history_edu_outlined,
        l10n.originTitle,
        () => go(() => context.push(AppRoutes.origin)),
      ),
      (
        Icons.flag_outlined,
        l10n.reportTitle,
        () => go(
          () => showReportSheet(
            context,
            regionName: region?.name.ar,
            date: selected,
          ),
        ),
      ),
    ];
    return Drawer(
      key: HomeScreen.drawerKey,
      width: 304,
      backgroundColor: Colors.transparent,
      child: GlassSurface(
        blur: true,
        radius: 0,
        fill: colors.surface.withValues(alpha: 0.92),
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                child: Text(
                  l10n.appTitle,
                  style: TextStyle(
                    fontFamily: DururFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ),
              for (final (i, (icon, label, onTap)) in items.indexed)
                ListTile(
                  key: HomeScreen.drawerItem(i),
                  minTileHeight: 56,
                  leading: Icon(icon, color: colors.primary),
                  title: Text(label),
                  onTap: onTap,
                ),
            ],
          ),
        ),
      ),
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
    final diameter = (width - 16).clamp(200.0, 560.0);
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
      for (final (o, i) in DialGeometry.gulfBands.values) ...[o, i],
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
  const _CalcError({
    required this.message,
    required this.onReport,
    this.inline = false,
  });

  final String message;
  final VoidCallback onReport;

  /// داخل صفحة قابلة للتمرير (مكان البطاقات، R3.4) لا قائمة مستقلة.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final children = [
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      OutlinedButton(
        key: HomeScreen.calcErrorReportKey,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: onReport,
        child: Text(AppLocalizations.of(context).reportTitle),
      ),
    ];
    if (inline) {
      return Padding(
        key: HomeScreen.calcErrorKey,
        padding: const EdgeInsetsDirectional.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }
    return ListView(
      key: HomeScreen.calcErrorKey,
      padding: const EdgeInsetsDirectional.all(24),
      children: children,
    );
  }
}
