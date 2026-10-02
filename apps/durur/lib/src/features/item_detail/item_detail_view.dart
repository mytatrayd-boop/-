import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../astronomy/heliacal.dart';
import '../../domain/local_date.dart';
import '../../domain/record_meta.dart';
import '../../formatting/date_labels.dart';
import '../../formatting/digits.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/chips.dart';
import 'detail_data.dart';

/// محتوى صفحة النجم/الموسم/الدَّرّ (SPEC الميزة 7، DESIGN 8.6)، نفسه في
/// الورقة السفلية (من الدائرة) والصفحة الكاملة (من البطاقة أو التنبيه).
class ItemDetailView extends ConsumerWidget {
  const ItemDetailView({
    super.key,
    required this.request,
    required this.onOpen,
    required this.onGoToStart,
    this.controller,
    this.header,
  });

  static const viewKey = Key('itemDetailView');
  static const rangeKey = Key('detailRange');
  static const statusKey = Key('detailStatus');
  static const astroKey = Key('detailAstro');
  static const definitionKey = Key('detailDefinition');
  static const proverbKey = Key('detailProverb');
  static const seasonChipKey = Key('detailSeasonChip');
  static const goToStartKey = Key('detailGoToStart');
  static const contentSourceKey = Key('detailContentSource');
  static const datesSourceKey = Key('detailDatesSource');
  static const pendingKey = Key('detailPending');

  final DetailRequest request;

  /// فتح صفحة أخرى (شريحة الموسم): داخل الورقة أو بمسار جديد.
  final void Function(DetailRequest request) onOpen;

  /// «انتقل إلى بدايته»: تدير الدائرة إلى [start] (تاريخ محلي).
  final void Function(DateTime start) onGoToStart;

  /// متحكم التمرير (ورقة قابلة للسحب).
  final ScrollController? controller;

  /// أعلى المحتوى داخل التمرير (أزرار الورقة).
  final Widget? header;

  /// يحسب المحتوى من المزوّدات، أو null إن لم يوجد العنصر/السجل.
  static DetailData? resolve(WidgetRef ref, DetailRequest request) {
    final tables = ref.watch(tablesProvider).value;
    if (tables == null) return null;
    return resolveDetail(
      tables: tables,
      engine: ref.watch(engineProvider),
      request: request,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider).value;
    final data = resolve(ref, request);
    if (tables == null || data == null) {
      return ListView(controller: controller, children: [?header]);
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final today = ref.watch(todayProvider);
    final period = data.period;
    final start = _local(period.start);
    final end = _local(period.end);
    final color = colors.season(data.seasonId ?? data.item?.id);
    final seasonName = data.seasonId == null
        ? null
        : tables.items[data.seasonId]?.name.ar;

    final children = <Widget>[
      ?header,
      ExcludeSemantics(child: SaduStrip(color: color)),
      const SizedBox(height: 12),
      Text(_typeLabel(l10n, data.kind), style: theme.textTheme.bodySmall),
      const SizedBox(height: 4),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            header: true,
            child: Text(data.name, style: theme.textTheme.displaySmall),
          ),
          if (seasonName != null)
            SeasonChip(
              key: seasonChipKey,
              label: data.kind == DetailKind.dar
                  ? l10n.detailDarHundred(seasonName)
                  : seasonName,
              color: color,
              onTap: () =>
                  onOpen((target: ItemTarget(data.seasonId!), from: start)),
            ),
        ],
      ),
      const SizedBox(height: 16),
      _DatesCard(
        data: data,
        start: start,
        end: end,
        today: today,
        onGoToStart: () => onGoToStart(start),
      ),
      if (data.item case final item?) ...[
        const SizedBox(height: 24),
        Text(
          item.definition.ar,
          key: definitionKey,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        _ProverbCard(text: item.proverb.ar, color: color),
      ],
      if (data.weather.isNotEmpty || data.weatherNote != null) ...[
        const SizedBox(height: 24),
        Text(l10n.homeUsualWeather, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in data.weather) WeatherChip(symbol: s)],
        ),
        if (data.weatherNote != null) ...[
          const SizedBox(height: 8),
          Text(data.weatherNote!.ar, style: theme.textTheme.bodyMedium),
        ],
      ],
      const SizedBox(height: 24),
      // المصدر لكل معلومة: نص العنصر من items.json، والتواريخ من سجل الجدول.
      if (data.item case final item?)
        _SourceLine(
          key: contentSourceKey,
          text: l10n.detailContentSource(_titles(item.sources, l10n)),
          approved: item.approval.isApproved,
        ),
      if (data.datesRecord case final record?)
        _SourceLine(
          key: datesSourceKey,
          text: data.item == null
              ? l10n.commonSource(_titles(record.sources, l10n))
              : l10n.detailDatesSource(_titles(record.sources, l10n)),
          approved: record.approval.isApproved,
        ),
      const SizedBox(height: 24),
    ];

    return ListView(
      key: viewKey,
      controller: controller,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      children: children,
    );
  }

  static String _typeLabel(AppLocalizations l10n, DetailKind kind) =>
      switch (kind) {
        DetailKind.star => l10n.detailTypeStar,
        DetailKind.season => l10n.detailTypeSeason,
        DetailKind.weatherSeason => l10n.detailTypeWeatherSeason,
        DetailKind.dar => l10n.detailTypeDar,
      };

  static String _titles(List<Source> sources, AppLocalizations l10n) =>
      sources.map((s) => s.title).toSet().join(l10n.listSeparator);
}

DateTime _local(DateTime utc) => DateTime(utc.year, utc.month, utc.day);

/// بطاقة التواريخ في منطقة المستخدم (DESIGN 8.6 بند 4).
class _DatesCard extends ConsumerWidget {
  const _DatesCard({
    required this.data,
    required this.start,
    required this.end,
    required this.today,
    required this.onGoToStart,
  });

  final DetailData data;
  final DateTime start;
  final DateTime end;
  final DateTime today;
  final VoidCallback onGoToStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final length = data.period.length;
    final digits = ref.watch(digitStyleProvider);

    final String status;
    if (today.isBefore(start)) {
      final days = daysBetween(today, start);
      status = l10n.detailStatusUpcoming(days, formatInteger(days, digits));
    } else if (today.isAfter(end)) {
      final days = daysBetween(end, today);
      status = l10n.detailStatusPast(days, formatInteger(days, digits));
    } else {
      status = l10n.detailStatusNow(
        formatInteger(daysBetween(start, today) + 1, digits),
        formatInteger(length, digits),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.detailRange(
                gregorianDateLabel(l10n, start, digits: digits),
                gregorianDateLabel(l10n, end, digits: digits),
                data.regionName,
              ),
              key: ItemDetailView.rangeKey,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.detailDuration(length, formatInteger(length, digits)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status,
              key: ItemDetailView.statusKey,
              style: theme.textTheme.titleSmall,
            ),
            if (data.isHeliacal) ...[
              const SizedBox(height: 12),
              _AstroLines(itemId: data.item!.id, year: start.year),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: ItemDetailView.goToStartKey,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onGoToStart,
                child: Text(l10n.detailGoToStart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// لسهيل والثريا: «يطلع في {مدينتك} يوم …» من الحساب الفلكي لمدينة
/// المستخدم (الميزة 5 معيار 4)، أو ملاحظة التاريخ التقريبي إن تعذّر.
class _AstroLines extends ConsumerWidget {
  const _AstroLines({required this.itemId, required this.year});

  final String itemId;
  final int year;

  /// تاريخ الطلوع المحسوب لعنصر، أو null إن لم يكن سهيل أو الثريا.
  static DateTime? risingOf(String itemId, HeliacalDates? dates) =>
      switch (itemId) {
        'suhail' => dates?.suhail,
        'thurayya' => dates?.thurayya,
        _ => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final digits = ref.watch(digitStyleProvider);
    final city = ref.watch(currentCityProvider);
    final today = ref.watch(todayProvider);
    final utc = risingOf(itemId, ref.watch(currentHeliacalProvider(year)));
    final caption = theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft);

    if (city == null || utc == null) {
      return Text(
        l10n.detailAstroFallback,
        key: ItemDetailView.astroKey,
        style: caption,
      );
    }
    final rising = _local(utc);
    final cityName = city.name.ar;
    final String line;
    if (rising.isAfter(today)) {
      line = l10n.detailStarRisesOn(cityName, gregorianDateLabel(l10n, rising, digits: digits));
    } else if (rising == today) {
      line = l10n.detailStarRisesToday(cityName);
    } else {
      final days = daysBetween(rising, today);
      line = l10n.detailStarRisenAgo(days, cityName, formatInteger(days, digits));
    }
    return Column(
      key: ItemDetailView.astroKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          line,
          style: theme.textTheme.titleMedium?.copyWith(color: colors.goldText),
        ),
        Text(l10n.detailAstroNote, style: caption),
      ],
    );
  }
}

/// بطاقة المثل الشعبي: خلفية لون الموسم 8%، علامة اقتباس زخرفية في
/// البداية، والمثل بخط Amiri (DESIGN 8.6 بند 6).
class _ProverbCard extends StatelessWidget {
  const _ProverbCard({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    return Container(
      key: ItemDetailView.proverbKey,
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(
              '”',
              style: TextStyle(
                fontFamily: DururFonts.proverb,
                fontSize: 48,
                height: 1,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.detailProverb, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: DururFonts.proverb,
                    fontSize: 20,
                    height: 34 / 20,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// سطر مصدر (`caption`)، ومعه «بانتظار الاعتماد» إن لم يعتمد المراجع السجل.
class _SourceLine extends StatelessWidget {
  const _SourceLine({super.key, required this.text, required this.approved});

  final String text;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.bodySmall),
          if (!approved) const PendingApprovalText(),
        ],
      ),
    );
  }
}

/// «بانتظار الاعتماد» بخط مائل `ink-soft` (المائل العربي بخط Amiri فقط،
/// DESIGN §3).
class PendingApprovalText extends StatelessWidget {
  const PendingApprovalText({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    return Text(
      AppLocalizations.of(context).approvalPending,
      key: ItemDetailView.pendingKey,
      style: TextStyle(
        fontFamily: DururFonts.proverb,
        fontStyle: FontStyle.italic,
        fontSize: 15,
        height: 1.6,
        color: colors.inkSoft,
      ),
    );
  }
}

/// شريط السدو الرفيع (4dp) بلون الموسم: نقش هندسي من معيّنات (DESIGN §1).
/// زخرفة مخفية عن قارئ الشاشة.
class SaduStrip extends StatelessWidget {
  const SaduStrip({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 4),
      painter: _SaduPainter(color, DururColors.of(context).surface),
    );
  }
}

class _SaduPainter extends CustomPainter {
  const _SaduPainter(this.color, this.gap);

  final Color color;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final h = size.height;
    final paint = Paint()..color = gap;
    for (var x = h; x < size.width; x += 3 * h) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + h / 2, h / 2)
        ..lineTo(x, h)
        ..lineTo(x - h / 2, h / 2)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SaduPainter old) => old.color != color || old.gap != gap;
}
