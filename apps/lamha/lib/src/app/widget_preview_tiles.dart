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
const dayTempSize = 28.0;
const capsuleSize = 16.0;
const columnTitleSize = 11.0;
const columnNameSize = 20.0;
const columnSubSize = 14.0;
const qiblaTitleSize = 14.0;
const pointSize = 12.0;

/// ارتفاعات الأسطر.
const dayLineHeight = 1.25;
const tempLineHeight = 1.15;
const pointLineHeight = 1.3;

/// تباعد: بين الأعمدة، وحول الكبسولة رأسياً، وحشوتها الأفقية والرأسية، وبين أسطر المربع.
const columnGap = 4.0;
const capsuleMargin = 3.0;
const capsulePadH = 12.0;
const capsulePadV = 2.0;
const lineGap = 2.0;

/// حشوة الصناديق الجديدة الرأسية (أقل من المربعات القديمة لتتسع الصفوف الخمسة).
const boxPadV = 4.0;

/// الكعبة نسبة من قطر دائرة القبلة، والعنوان حتى [qiblaTitleRatio] من القطر.
const kaabaRatio = 0.42;
const kaabaAloneRatio = 0.55;
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

  /// مقاسه بالسطرين الأساسيين (اليوم والحرارة)؛ سطر المدينة إن اتسع.
  @override
  ({double text, double pad}) heights(BuildContext context, double width) => (
    text:
        (dayWeekdaySize * dayLineHeight +
            (look.showSub ? dayTempSize * tempLineHeight : 0)) *
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
        fontWeight: FontWeight.w500,
        height: tempLineHeight,
        color: secondary,
      );
      final words = _words(context, weekday, dayStyle);
      final fit = fitTile(
        height: c.maxHeight,
        width: c.maxWidth - fitMargin,
        valueLineHeight: dayWeekdaySize * s * dayLineHeight,
        valueWords: words.words,
        valueSpace: words.space,
        subs: [
          if (look.showSub) ...[
            (height: dayCitySize * s * headLineHeight, maxLines: 1, fitWidth: 0),
            (
              height: dayTempSize * s * tempLineHeight,
              maxLines: 1,
              fitWidth: _measure(context, temp, tempStyle),
            ),
          ],
        ],
        hideFromStart: true,
        minSubFit: headMinFit,
      );
      final texts = [city, temp];
      final styles = [cityStyle, tempStyle];
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
      (text: look.showTitle ? qiblaTitleSize * tileLineHeight * s : 0, pad: 32);

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

/// الإيداعات: «متبقي على:» ثم عمود لكل إيداع (حتى ثلاثة، الأقرب أولاً): الاسم وتحته الأيام.
class _DepositsTile extends _ColumnsTile {
  const _DepositsTile({
    required super.items,
    required String super.title,
    super.look,
  }) : super(keyPrefix: 'deposit');

  @override
  _DepositsTile withLook(_Look look) =>
      _DepositsTile(items: items, title: title!, look: look);
}

/// وصف الموسم: «في الوسم:» ثم نقاط تبدأ بـ«-». إن ضاق الارتفاع تُخفى النقاط من الآخر، ثم العنوان.
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

  /// مقاسه بالعنوان وسطرين؛ بقية النقاط إن اتسعت.
  @override
  ({double text, double pad}) heights(BuildContext context, double width) => (
    text:
        ((look.showTitle ? columnTitleSize * tileLineHeight : 0) +
            pointSize * pointLineHeight * 2) *
        s,
    pad: boxPadV * 2 + lineGap,
  );

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
        final words = [for (final p in points) _words(context, p, pointStyle)];
        final lines = [
          for (final w in words) wrapLines(w.words, w.space, width),
        ];
        final line = pointSize * s * pointLineHeight;
        final titleFits =
            look.showTitle && _measure(context, title, titleStyle) <= width;
        final fit = fitTile(
          height: c.maxHeight,
          width: width,
          titleHeight: titleFits ? columnTitleSize * s * tileLineHeight : 0,
          valueLineHeight: points.isEmpty ? 0 : line,
          valueWords: points.isEmpty ? const [] : words.first.words,
          valueSpace: points.isEmpty ? 0 : words.first.space,
          subs: [
            if (look.showSub)
              for (var i = 1; i < points.length; i++)
                (height: lines[i] * line, maxLines: 1, fitWidth: 0),
          ],
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
                if (points.isNotEmpty) ...[
                  if (fit.title) const SizedBox(height: lineGap),
                  Text(
                    points.first,
                    key: const Key('point-0'),
                    textAlign: TextAlign.right,
                    maxLines: fit.valueLines,
                    style: pointStyle.copyWith(
                      fontSize: pointSize * s * fit.valueScale,
                    ),
                  ),
                ],
                for (final i in fit.subs) ...[
                  const SizedBox(height: lineGap),
                  Text(
                    points[i + 1],
                    key: Key('point-${i + 1}'),
                    textAlign: TextAlign.right,
                    maxLines: lines[i + 1],
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
