part of 'widget_preview.dart';

/// مربعات تصميم المالك ٣ (الميزة ٦، `mockups/owner_design_v3.png`): اليوم والطقس، وكبسولتا
/// التاريخين، ودائرة القبلة، ومربعا الأعمدة (مواقيت الصلاة والإيداعات)، ووصف الموسم. مطابقة لـ
/// LamhaWidgetReceiver.kt وتخطيطاتها (widget_tile_dayweather وcapsule وqibla وcolumns وpoints).

/// الصناديق رمادية مزرقة نصف شفافة فوق خلفية السمة (tile_bg.xml)، ومربع مواقيت الصلاة أفتح
/// (tile_bg_light.xml)، ودائرة القبلة زرقاء داكنة (qibla_circle.xml).
const tileBoxColor = Color(0x4096AAD2);
const tileBoxLightColor = Color(0x5C96AAD2);
const qiblaCircleColor = Color(0xFF1F2A44);
const tileRadius = 18.0;
const capsuleRadius = 14.0;

/// أحجام الميزة ٦ قبل معامل الخط، بنسب تصميم المالك إلى عرض الودجت (٣٣٨): الساعة أكبرها، ثم
/// الحرارة واليوم، ثم أسماء الصلوات والإيداعات بحجم القيم، والأوقات والأيام أصغر قليلاً.
const dayWeekdaySize = 22.0;
const dayCitySize = 16.0;
const dayTempSize = 24.0;

/// سطر المدينة يصغر حتى هذا الحجم ثم «…»، ولا يُخفى.
const dayCityMinSize = 13.0;
const capsuleSize = 16.0;
const columnTitleSize = 11.0;
const columnNameSize = 20.0;
const columnSubSize = 14.0;

/// شبكة الإيداعات (أكثر من ثلاثة): الاسم ١٦ عادي (طلب المالك) وبجانبه الأيام ١٤.
const gridNameSize = 16.0;
const gridDaysSize = 14.0;

/// بين الاسم وعمود الأيام في الشبكة.
const gridDaysGap = 6.0;

/// هامش عمود الأيام لتقريب البكسل.
const gridDaysSlack = 2.0;
const qiblaTitleSize = 14.0;
const pointSize = 10.0;

/// ارتفاعات الأسطر.
const dayLineHeight = 1.15;
const tempLineHeight = 1.15;
const pointLineHeight = 1.3;

/// تباعد: بين الأعمدة، وحول الكبسولة رأسياً، وحشوتها الأفقية والرأسية، وبين أسطر المربع.
const columnGap = 4.0;
const capsuleMargin = 2.0;
const capsulePadH = 12.0;
const capsulePadV = 1.0;
const lineGap = 2.0;

/// حشوة الصناديق الجديدة الرأسية (أقل من المربعات القديمة لتتسع الصفوف الخمسة).
const boxPadV = 2.0;

/// الكعبة نسبة من قطر دائرة القبلة، والعنوان حتى [qiblaTitleRatio] من القطر.
const kaabaRatio = 0.5;
const kaabaAloneRatio = 0.6;
const qiblaTitleRatio = 0.16;

/// مربع في الشبكة: يُرسم بحجمه المطلوب داخل مقاسه، ومقاسه من [base] بالحجم الأساسي.
abstract class _Cell extends StatelessWidget {
  const _Cell();

  _Cell styled({
    required double scale,
    required bool showTitle,
    required bool showSub,
    Color? primary,
    Color? secondary,
  });

  _Cell get base;

  ({double text, double pad}) heights(BuildContext context, double width);
}

typedef _Look = ({
  double scale,
  bool showTitle,
  bool showSub,
  Color? primary,
  Color? secondary,
});

const _Look _defaultLook = (
  scale: 1.0,
  showTitle: true,
  showSub: true,
  primary: null,
  secondary: null,
);

abstract class _Styled extends _Cell {
  const _Styled(this.look);

  final _Look look;

  _Styled withLook(_Look look);

  @override
  _Styled styled({
    required double scale,
    required bool showTitle,
    required bool showSub,
    Color? primary,
    Color? secondary,
  }) => withLook((
    scale: scale,
    showTitle: showTitle,
    showSub: showSub,
    primary: primary,
    secondary: secondary,
  ));

  /// بالحجم الأساسي، والمفتاحان المطفآن لا يأخذان مكاناً (الميزة ٦).
  @override
  _Styled get base => withLook((
    scale: 1,
    showTitle: look.showTitle,
    showSub: look.showSub,
    primary: look.primary,
    secondary: look.secondary,
  ));

  double get s => look.scale;
  Color get primary => look.primary ?? _text;
  Color get secondary => look.secondary ?? _dim;
}

/// صندوق رمادي مزرق بزوايا كبيرة.
Widget _boxed(Widget child, {Color color = tileBoxColor}) => DecoratedBox(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(tileRadius),
    color: color,
  ),
  child: Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: tilePadH,
      vertical: boxPadV,
    ),
    child: child,
  ),
);

/// يوسّط [child] رأسياً، ويقص ما يزيد (أمان؛ fitTile يمنعه).
Widget _centered(Widget child) => ClipRect(
  child: OverflowBox(
    alignment: AlignmentDirectional.centerStart,
    minHeight: 0,
    maxHeight: double.infinity,
    child: child,
  ),
);

/// اليوم والطقس (بلا صندوق): اليوم كبير عريض، ثم «📍 المدينة ☀️» باللون الفرعي، ثم الحرارة كبيرة.
/// إن ضاق الارتفاع يُخفى سطر المدينة أولاً ثم الحرارة.
class _DayWeatherTile extends _Styled {
  const _DayWeatherTile({
    required this.weekday,
    required this.city,
    required this.temp,
    _Look look = _defaultLook,
  }) : super(look);

  final String weekday;
  final String city;
  final String temp;

  @override
  _DayWeatherTile withLook(_Look look) =>
      _DayWeatherTile(weekday: weekday, city: city, temp: temp, look: look);

  /// مقاسه بأسطره الثلاثة (المدينة بحجمها الأدنى).
  @override
  ({double text, double pad}) heights(BuildContext context, double width) => (
    text:
        (dayWeekdaySize * dayLineHeight +
            (look.showSub
                ? dayCityMinSize * headLineHeight +
                      dayTempSize * tempLineHeight
                : 0)) *
        s,
    pad: 0,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final dayStyle = TextStyle(
        fontSize: dayWeekdaySize * s,
        fontWeight: FontWeight.w700,
        height: dayLineHeight,
        color: primary,
      );
      final cityStyle = TextStyle(
        fontSize: dayCitySize * s,
        height: headLineHeight,
        color: secondary,
      );
      final tempStyle = TextStyle(
        fontSize: dayTempSize * s,
        fontWeight: FontWeight.w700,
        height: tempLineHeight,
        color: secondary,
      );
      final words = _words(context, weekday, dayStyle);
      // المدينة تصغر حتى ١٣ ثم «…»، ولا تُخفى.
      final cityWidth = _measure(context, city, cityStyle);
      final avail = c.maxWidth - fitMargin;
      final cityK = cityWidth > avail
          ? math.max(dayCityMinSize / dayCitySize, avail / cityWidth)
          : 1.0;
      var cityK2 = cityK;
      // وإن لم تتسع الأسطر الثلاثة رأسياً تصغر المدينة إلى ١٣ قبل إخفاء الحرارة.
      if (c.maxHeight > 0 &&
          (dayWeekdaySize * dayLineHeight +
                      dayCitySize * cityK * headLineHeight +
                      dayTempSize * tempLineHeight) *
                  s >
              c.maxHeight) {
        cityK2 = math.min(cityK, dayCityMinSize / dayCitySize);
      }
      final citySized = cityStyle.copyWith(fontSize: dayCitySize * s * cityK2);
      final fit = fitTile(
        height: c.maxHeight,
        width: avail,
        valueLineHeight: dayWeekdaySize * s * dayLineHeight,
        valueWords: words.words,
        valueSpace: words.space,
        subs: [
          if (look.showSub) ...[
            (
              height: dayCitySize * s * cityK2 * headLineHeight,
              maxLines: 1,
              fitWidth: 0,
            ),
            (
              height: dayTempSize * s * tempLineHeight,
              maxLines: 1,
              fitWidth: _measure(context, temp, tempStyle),
            ),
          ],
        ],
        minSubFit: headMinFit,
      );
      final texts = [city, temp];
      final styles = [citySized, tempStyle];
      final keys = const [Key('preview-city'), Key('preview-temp')];
      return _centered(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              weekday,
              key: const Key('preview-day'),
              textAlign: TextAlign.right,
              maxLines: fit.valueLines,
              style: dayStyle.copyWith(
                fontSize: dayWeekdaySize * s * fit.valueScale,
              ),
            ),
            for (final (j, i) in fit.subs.indexed)
              Text(
                texts[i],
                key: keys[i],
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles[i].copyWith(
                  fontSize: styles[i].fontSize! * fit.subScales[j],
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// تاريخ في كبسولة مستقلة (الهجري أو الميلادي)، محاذى يميناً ومتوسط رأسياً.
class _CapsuleTile extends _Styled {
  const _CapsuleTile({
    required this.kind,
    required this.text,
    _Look look = _defaultLook,
  }) : super(look);

  final WidgetElement kind;
  final String text;

  @override
  _CapsuleTile withLook(_Look look) =>
      _CapsuleTile(kind: kind, text: text, look: look);

  @override
  ({double text, double pad}) heights(BuildContext context, double width) => (
    text: capsuleSize * headLineHeight * s,
    pad: 2 * (capsuleMargin + capsulePadV),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: capsuleMargin),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(capsuleRadius),
        color: tileBoxColor,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: capsulePadH,
          vertical: capsulePadV,
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final style = TextStyle(
              fontSize: capsuleSize * s,
              fontWeight: FontWeight.w700,
              height: headLineHeight,
              color: primary,
            );
            final words = _words(context, text, style);
            final fit = fitTile(
              height: c.maxHeight,
              width: c.maxWidth - fitMargin,
              valueLineHeight: capsuleSize * s * headLineHeight,
              valueWords: words.words,
              valueSpace: words.space,
            );
            return _centered(
              Text(
                text,
                key: Key('preview-${kind.name}'),
                textAlign: TextAlign.right,
                maxLines: fit.valueLines,
                style: style.copyWith(
                  fontSize: capsuleSize * s * fit.valueScale,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// حجم عنوان دائرة القبلة: المطلوب، حتى [qiblaTitleRatio] من القطر [d]، وعرضه حتى ٧٠٪ منه
/// (qiblaTitleSp في LamhaWidgetReceiver.kt).
double qiblaTitleFit(double preferred, double widthAtPreferred, double d) {
  final byHeight = math.min(preferred, d * qiblaTitleRatio);
  return fitTextSize(
    byHeight,
    widthAtPreferred * byHeight / preferred,
    d * 0.7,
    0,
  );
}

/// القبلة: دائرة زرقاء داكنة فيها «القبلة» وتحتها الكعبة (استثناء «لا أيقونات»: رسمها المالك).
class _QiblaTile extends _Styled {
  const _QiblaTile({required this.title, _Look look = _defaultLook})
    : super(look);

  final String title;

  @override
  _QiblaTile withLook(_Look look) => _QiblaTile(title: title, look: look);

  @override
  ({double text, double pad}) heights(BuildContext context, double width) =>
      (text: look.showTitle ? qiblaTitleSize * tileLineHeight * s : 0, pad: 36);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final d = math.min(c.maxWidth, c.maxHeight);
      final style = TextStyle(
        fontSize: qiblaTitleSize * s,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: primary,
      );
      final size = qiblaTitleFit(
        qiblaTitleSize * s,
        _measure(context, title, style),
        d,
      );
      final kaaba = d * (look.showTitle ? kaabaRatio : kaabaAloneRatio);
      return Center(
        child: SizedBox.square(
          dimension: d,
          child: DecoratedBox(
            key: const Key('preview-qibla-circle'),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: qiblaCircleColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (look.showTitle)
                  Text(
                    title,
                    key: const Key('preview-qibla-title'),
                    maxLines: 1,
                    softWrap: false,
                    style: style.copyWith(fontSize: size),
                  ),
                SizedBox.square(
                  key: const Key('preview-kaaba'),
                  dimension: kaaba,
                  child: const CustomPaint(painter: KaabaPainter()),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

typedef _ColumnItem = ({String name, String sub});

/// مربع أعمدة: كل عمود اسم (بحجم القيمة) وتحته سطر أصغر، من اليمين. [accent] يميّز العمود الأول
/// (الصلاة القادمة)، و[title] عنوان صغير فوق الأعمدة («متبقي على:»). الأعمدة تصغر بالتساوي ولا
/// يُخفى عمود (fitColumns).
class _ColumnsTile extends _Styled {
  const _ColumnsTile({
    required this.keyPrefix,
    required this.items,
    this.title,
    this.accent,
    this.light = false,
    _Look look = _defaultLook,
  }) : super(look);

  /// بادئة مفاتيح الاختبار («prayer» أو «deposit»).
  final String keyPrefix;
  final List<_ColumnItem> items;
  final String? title;
  final Color? accent;
  final bool light;

  @override
  _ColumnsTile withLook(_Look look) => _ColumnsTile(
    keyPrefix: keyPrefix,
    items: items,
    title: title,
    accent: accent,
    light: light,
    look: look,
  );

  /// مقاسه بالسطرين الأساسيين (الاسم وتحته)؛ العنوان إن اتسع.
  @override
  ({double text, double pad}) heights(BuildContext context, double width) => (
    text:
        (columnNameSize + (look.showSub ? columnSubSize : 0)) *
        tileLineHeight *
        s,
    pad: boxPadV * 2 + (look.showSub ? lineGap : 0),
  );

  @override
  Widget build(BuildContext context) => _boxed(
    color: light ? tileBoxLightColor : tileBoxColor,
    LayoutBuilder(
      builder: (context, c) {
        final n = math.max(1, items.length);
        final colWidth = (c.maxWidth - columnGap * (n - 1)) / n - fitMargin;
        final titleStyle = TextStyle(
          fontSize: columnTitleSize * s,
          fontWeight: FontWeight.w700,
          height: tileLineHeight,
          color: secondary,
        );
        final nameStyle = TextStyle(
          fontSize: columnNameSize * s,
          fontWeight: FontWeight.w700,
          height: tileLineHeight,
          color: primary,
        );
        final subStyle = TextStyle(
          fontSize: columnSubSize * s,
          fontWeight: FontWeight.w500,
          height: tileLineHeight,
          color: secondary,
        );
        double widest(Iterable<String> t, TextStyle st) =>
            t.fold(0.0, (a, x) => math.max(a, _measure(context, x, st)));
        final fit = fitColumns(
          height: c.maxHeight,
          width: colWidth,
          titleHeight: title != null && look.showTitle
              ? columnTitleSize * s * tileLineHeight
              : 0,
          nameLine: columnNameSize * s * tileLineHeight,
          nameWidth: widest(items.map((i) => i.name), nameStyle),
          subLine: look.showSub ? columnSubSize * s * tileLineHeight : 0,
          subWidth: widest(items.map((i) => i.sub), subStyle),
          gap: lineGap,
        );
        return _centered(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fit.title) ...[
                Text(
                  title!,
                  key: Key('$keyPrefix-title'),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  softWrap: false,
                  style: titleStyle,
                ),
                const SizedBox(height: lineGap),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, item) in items.indexed) ...[
                    if (i > 0) const SizedBox(width: columnGap),
                    Expanded(
                      child: Column(
                        key: Key('$keyPrefix-column-$i'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.name,
                            key: Key('$keyPrefix-name-$i'),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            softWrap: false,
                            style: nameStyle.copyWith(
                              fontSize: columnNameSize * s * fit.nameScale,
                              color: i == 0 && accent != null ? accent : null,
                            ),
                          ),
                          if (fit.sub) ...[
                            const SizedBox(height: lineGap),
                            Text(
                              item.sub,
                              key: Key('$keyPrefix-sub-$i'),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              softWrap: false,
                              style: subStyle.copyWith(
                                fontSize: columnSubSize * s * fit.subScale,
                                color: i == 0 && accent != null
                                    ? accent
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// مواقيت الصلاة: خمسة أعمدة تبدأ بالقادمة (rotatePrayers) مميَّزة بلون التمييز، في صندوق أفتح.
class _PrayerTimesTile extends _ColumnsTile {
  const _PrayerTimesTile({
    required super.items,
    required Color super.accent,
    super.look,
  }) : super(keyPrefix: 'prayer', light: true);

  @override
  _PrayerTimesTile withLook(_Look look) =>
      _PrayerTimesTile(items: items, accent: accent!, look: look);
}

/// الإيداعات: عمود لكل إيداع (حتى ثلاثة، الأقرب أولاً): الاسم وتحته الأيام، بلا عنوان (طلب المالك).
class _DepositsTile extends _ColumnsTile {
  const _DepositsTile({required super.items, super.look})
    : super(keyPrefix: 'deposit');

  @override
  _DepositsTile withLook(_Look look) => _DepositsTile(items: items, look: look);
}

/// الإيداعات بعد الثلاثة (طلب المالك): شبكة عمودين بلا عنوان، لكل خانة الاسم وبجانبه الأيام
/// في سطر واحد، الأقرب أولاً من اليمين. الأيام كجدول: عمود بعرض أعرضها فتبدأ كلها من موضع واحد.
/// الخانات تصغر بالتساوي، وإن ضاق الارتفاع تصغر الصفوف (fitGrid). مطابقة لـ gridTile في LamhaWidgetReceiver.kt.
class _DepositsGridTile extends _Styled {
  const _DepositsGridTile({required this.items, _Look look = _defaultLook})
    : super(look);

  final List<_ColumnItem> items;

  int get _rows => gridRows(items.length);

  @override
  _DepositsGridTile withLook(_Look look) =>
      _DepositsGridTile(items: items, look: look);

  /// مقاسه بالصفوف.
  @override
  ({double text, double pad}) heights(BuildContext context, double width) => (
    text: _rows * gridNameSize * tileLineHeight * s,
    pad: boxPadV * 2 + lineGap * (_rows - 1),
  );

  @override
  Widget build(BuildContext context) => _boxed(
    LayoutBuilder(
      builder: (context, c) {
        final cellWidth = (c.maxWidth - columnGap) / 2 - fitMargin;
        final nameStyle = TextStyle(
          fontSize: gridNameSize * s,
          fontWeight: FontWeight.w400,
          height: tileLineHeight,
          color: primary,
        );
        final daysStyle = TextStyle(
          fontSize: gridDaysSize * s,
          fontWeight: FontWeight.w500,
          height: tileLineHeight,
          color: secondary,
        );
        double widest(Iterable<String> t, TextStyle st) =>
            t.fold(0.0, (a, x) => math.max(a, _measure(context, x, st)));
        final nameW = widest(items.map((i) => i.name), nameStyle);
        final daysW = look.showSub
            ? widest(items.map((i) => i.sub), daysStyle)
            : 0.0;
        // الفاصل وهامش عمود الأيام لا يصغران مع النص، فيُطرحان من العرض.
        final fixed = look.showSub ? gridDaysGap + gridDaysSlack : 0.0;
        final fit = fitGrid(
          height: c.maxHeight,
          width: math.max(1.0, cellWidth - fixed),
          line: gridNameSize * s * tileLineHeight,
          cellWidth: nameW + daysW,
          rows: _rows,
          gap: lineGap,
        );
        // عمود الأيام بعرض أعرضها بعد التصغير (+ هامش للتقريب)، والاسم ما بقي.
        final daysColumn = daysW * fit.scale + gridDaysSlack;
        Widget text(int i) {
          if (i >= items.length) return const SizedBox.shrink();
          final item = items[i];
          return Row(
            key: Key('deposit-cell-$i'),
            children: [
              Expanded(
                child: Text(
                  item.name,
                  key: Key('deposit-name-$i'),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle.copyWith(
                    fontSize: gridNameSize * s * fit.scale,
                  ),
                ),
              ),
              if (look.showSub) ...[
                const SizedBox(width: gridDaysGap),
                SizedBox(
                  width: daysColumn,
                  child: Text(
                    item.sub,
                    key: Key('deposit-days-$i'),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                    style: daysStyle.copyWith(
                      fontSize: gridDaysSize * s * fit.scale,
                    ),
                  ),
                ),
              ],
            ],
          );
        }

        return _centered(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var r = 0; r < _rows; r++) ...[
                if (r > 0) const SizedBox(height: lineGap),
                Row(
                  key: Key('deposit-row-$r'),
                  children: [
                    Expanded(child: text(r * 2)),
                    const SizedBox(width: columnGap),
                    Expanded(child: text(r * 2 + 1)),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

/// وصف الموسم: «في الوسم:» ثم نقاط ١٠ تبدأ بـ«-»، لكل نقطة حتى ثلاثة أسطر. إن ضاق الارتفاع تُخفى النقاط من الآخر، ثم العنوان.
class _PointsTile extends _Styled {
  const _PointsTile({
    required this.title,
    required this.points,
    _Look look = _defaultLook,
  }) : super(look);

  final String title;
  final List<String> points;

  @override
  _PointsTile withLook(_Look look) =>
      _PointsTile(title: title, points: points, look: look);

  /// مقاسه بنقطتين بسطرين لكل منهما؛ العنوان إن اتسع.
  @override
  ({double text, double pad}) heights(BuildContext context, double width) =>
      (text: pointSize * pointLineHeight * 4 * s, pad: boxPadV * 2 + lineGap);

  @override
  Widget build(BuildContext context) => _boxed(
    LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth - fitMargin;
        final titleStyle = TextStyle(
          fontSize: columnTitleSize * s,
          fontWeight: FontWeight.w700,
          height: tileLineHeight,
          color: secondary,
        );
        final pointStyle = TextStyle(
          fontSize: pointSize * s,
          height: pointLineHeight,
          color: primary,
        );
        final shown = look.showSub ? points : points.take(1).toList();
        final lines = [
          for (final p in shown)
            () {
              final w = _words(context, p, pointStyle);
              return wrapLines(w.words, w.space, width);
            }(),
        ];
        final line = pointSize * s * pointLineHeight;
        final titleFits =
            look.showTitle && _measure(context, title, titleStyle) <= width;
        // النقاط قبل العنوان، ولكل نقطة ثلاثة أسطر حداً (fitPoints)؛ نص المالك لا يُقص.
        final fit = fitPoints(
          height: c.maxHeight,
          titleHeight: titleFits ? columnTitleSize * s * tileLineHeight : 0,
          line: line,
          lines: lines,
          gap: lineGap,
        );
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fit.title)
                  Text(
                    title,
                    key: const Key('points-title'),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                    style: titleStyle,
                  ),
                for (final (i, max) in fit.lines.indexed) ...[
                  if (i > 0 || fit.title) const SizedBox(height: lineGap),
                  Text(
                    shown[i],
                    key: Key('point-$i'),
                    textAlign: TextAlign.right,
                    maxLines: max,
                    overflow: TextOverflow.ellipsis,
                    style: pointStyle,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
