part of 'widget_preview.dart';

/// مربعات تصميم المالك ٣ (الميزة ٦، `mockups/owner_design_v3.png`): اليوم والطقس، وكبسولتا
/// التاريخين، وأيقونة القبلة، ومربعا الأعمدة (مواقيت الصلاة والإيداعات)، ووصف الموسم. مطابقة لـ
/// LamhaWidgetReceiver.kt وتخطيطاتها (widget_tile_dayweather وcapsule وqibla وcolumns وpoints).

/// الصناديق رمادية مزرقة نصف شفافة فوق خلفية السمة (tile_bg.xml)، ومربع مواقيت الصلاة أفتح
/// (tile_bg_light.xml).
const tileBoxColor = Color(0x4096AAD2);
const tileBoxLightColor = Color(0x5C96AAD2);
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

/// الإيداعات (طلب المالك): كل إيداع في مستطيل، الاسم والأيام بحجم واحد ١٦.
const depositSize = 16.0;
const depositPadH = 10.0;
const depositPadV = 4.0;
const depositRowGap = 4.0;
const depositRadius = 12.0;

/// بين الاسم وعمود الأيام في الشبكة.
const gridDaysGap = 6.0;

/// هامش عمود الأيام لتقريب البكسل.
const gridDaysSlack = 2.0;
const qiblaTitleSize = 14.0;

/// السطر الصغير تحت زاوية القبلة («من الشمال · شمال غرب»).
const qiblaSubSize = 9.0;
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

/// مربع القبلة (صورة المالك، أكتوبر ٢٠٢٦): بوصلة سوداء مستديرة بتدريج أبيض وحروف N وE وS وW، ونجمة
/// داكنة في الوسط، وسهم أحمر من المركز ثم خط منقّط أحمر إلى الكعبة على المحيط بزاوية القبلة من
/// الشمال. وبين المربع والزاوية تحته [qiblaIconGap].
const qiblaIconGap = 2.0;

/// صورة الكعبة الأصلية (من أيقونة القبلة) بخلفية شفافة، للمربع وشاشة البوصلة.
const kaabaAsset = 'assets/branding/kaaba.png';
const qiblaDialFace = Color(0xFF000000);
const qiblaDialTicks = Color(0xFFFFFFFF);
const qiblaDialStar = Color(0xFF3A3A3A);
const qiblaDialArrow = Color(0xFFE53935);

/// الأبعاد نسبةً لضلع المربع (مطابقة لـ drawQiblaDial في LamhaWidgetReceiver.kt وQiblaIcon في
/// LamhaWidget.swift): نصف قطر القرص، وطرفا التدريج، وموضع الحروف وحجمها، وبعد الكعبة عن المركز
/// وضلعها، وطول السهم ونصف عرضه، وطول النجمة.
const qiblaDialRadius = 0.49;
const qiblaTickOuter = 0.46;
const qiblaTickInner = 0.41;
const qiblaTickLong = 0.38;
const qiblaLetterAt = 0.36;
const qiblaLetterSize = 0.13;
const qiblaKaabaAt = 0.36;
const qiblaKaabaSize = 0.18;
const qiblaArrowLength = 0.24;
const qiblaArrowHalf = 0.07;
const qiblaStarLength = 0.2;

/// مركز الكعبة في مربع القبلة (نسبةً للضلع، من أعلى اليسار) عند زاوية [degrees] من الشمال.
Offset qiblaKaabaCenter(double degrees) {
  final a = degrees * math.pi / 180;
  return Offset(0.5 + math.sin(a) * qiblaKaabaAt, 0.5 - math.cos(a) * qiblaKaabaAt);
}

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
                ? dayCityMinSize * headLineHeight + dayTempSize * tempLineHeight
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

/// القبلة (lamha_qibla_update.md): دائرة اتجاه ثابت محسوب من الموقع (الودجت لا تقرأ الحساس) فوق خلفية
/// أيقونة القبلة (qiblaIconBackground بلون التمييز أو اللون الرئيسي للمربع)، وتحتها الزاوية بخط كبير
/// («٣٢٥°») ثم سطر صغير («من الشمال · شمال غرب»). الدائرة أكبر مربع يتسع مع السطرين، والسطران يصغران
/// ليتسعا عرض المربع. الضغط يفتح شاشة البوصلة. مطابقة لـ qiblaTile في LamhaWidgetReceiver.kt.
class _QiblaTile extends _Styled {
  const _QiblaTile({
    required this.angle,
    required this.sub,
    required this.degrees,
    required this.accent,
    this.faceAlpha = 1,
    _Look look = _defaultLook,
  }) : super(look);

  final String angle;
  final String sub;
  final double degrees;
  final Color accent;

  /// شفافية قرص البوصلة = شفافية خلفية الودجت (backgroundAlpha).
  final double faceAlpha;

  @override
  _QiblaTile withLook(_Look look) => _QiblaTile(
    angle: angle,
    sub: sub,
    degrees: degrees,
    accent: accent,
    faceAlpha: faceAlpha,
    look: look,
  );

  @override
  ({double text, double pad}) heights(BuildContext context, double width) => (
    text: look.showTitle
        ? (qiblaTitleSize + qiblaSubSize) * tileLineHeight * s
        : 0,
    pad: qiblaIconTarget(width),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      TextStyle style(double size, Color color, FontWeight weight) => TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: tileLineHeight,
        color: color,
      );
      double fit(String text, TextStyle st) => fitTextSize(
        st.fontSize!,
        _measure(context, text, st),
        c.maxWidth - fitMargin,
        st.fontSize! * 0.6,
      );
      final angleStyle = style(qiblaTitleSize * s, primary, FontWeight.w700);
      final subStyle = style(qiblaSubSize * s, secondary, FontWeight.w500);
      final angleSize = fit(angle, angleStyle);
      final subSize = fit(sub, subStyle);
      // +١ لتقريب ارتفاع السطر.
      final textLines = look.showTitle
          ? (angleSize + subSize) * tileLineHeight + qiblaIconGap + 1
          : 0;
      final icon = math.max(0.0, math.min(c.maxWidth, c.maxHeight - textLines));
      return _centered(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                key: const Key('preview-qibla-icon'),
                dimension: icon,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        key: const Key('preview-qibla-dial'),
                        painter: QiblaTileDialPainter(degrees, faceAlpha: faceAlpha),
                      ),
                    ),
                    Positioned(
                      left: (qiblaKaabaCenter(degrees).dx - qiblaKaabaSize / 2) * icon,
                      top: (qiblaKaabaCenter(degrees).dy - qiblaKaabaSize / 2) * icon,
                      width: icon * qiblaKaabaSize,
                      height: icon * qiblaKaabaSize,
                      child: Image.asset(
                        kaabaAsset,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ],
                ),
              ),
              if (look.showTitle) ...[
                const SizedBox(height: qiblaIconGap),
                Text(
                  angle,
                  key: const Key('preview-qibla-title'),
                  maxLines: 1,
                  softWrap: false,
                  style: angleStyle.copyWith(fontSize: angleSize),
                ),
                Text(
                  sub,
                  key: const Key('preview-qibla-sub'),
                  maxLines: 1,
                  softWrap: false,
                  style: subStyle.copyWith(fontSize: subSize),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// قرص مربع القبلة (صورة المالك): دائرة سوداء، وتدريج أبيض كل ١٠° (أطول كل ٣٠°)، وحروف الجهات
/// بيضاء، ونجمة داكنة، وسهم أحمر من المركز بزاوية [degrees] من الشمال، وخط منقّط أحمر منه إلى
/// الكعبة (صورة فوق القرص عند [qiblaKaabaCenter]).
class QiblaTileDialPainter extends CustomPainter {
  QiblaTileDialPainter(this.degrees, {this.faceAlpha = 1});

  final double degrees;

  /// ٠–١: القرص الأسود يتبع شفافية خلفية الودجت، والتدريج والسهم يبقيان.
  final double faceAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, side * qiblaDialRadius, Paint()..color = qiblaDialFace.withValues(alpha: faceAlpha));
    for (var d = 0; d < 360; d += 10) {
      if (d % 90 == 0) continue;
      final a = d * math.pi / 180;
      final dir = Offset(math.sin(a), -math.cos(a));
      final long = d % 30 == 0;
      canvas.drawLine(
        c + dir * side * (long ? qiblaTickLong : qiblaTickInner),
        c + dir * side * qiblaTickOuter,
        Paint()
          ..color = qiblaDialTicks
          ..strokeWidth = side * (long ? 0.022 : 0.014)
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final (d, label) in [(0, 'N'), (90, 'E'), (180, 'S'), (270, 'W')]) {
      final a = d * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: qiblaDialTicks, fontSize: side * qiblaLetterSize, fontWeight: FontWeight.w700, height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + Offset(math.sin(a), -math.cos(a)) * side * qiblaLetterAt;
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final len = side * qiblaStarLength * (i.isEven ? 1 : 0.6);
      final w = side * 0.035;
      final tip = c + Offset(math.sin(a), -math.cos(a)) * len;
      final n = Offset(math.cos(a), math.sin(a)) * w;
      canvas.drawPath(Path()..moveTo(c.dx + n.dx, c.dy + n.dy)..lineTo(tip.dx, tip.dy)..lineTo(c.dx - n.dx, c.dy - n.dy)..close(),
          Paint()..color = qiblaDialStar);
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(degrees * math.pi / 180);
    final red = Paint()..color = qiblaDialArrow;
    canvas.drawPath(
      Path()
        ..moveTo(0, -side * qiblaArrowLength)
        ..lineTo(side * qiblaArrowHalf, side * 0.03)
        ..lineTo(0, -side * 0.02)
        ..lineTo(-side * qiblaArrowHalf, side * 0.03)
        ..close(),
      red,
    );
    final dot = Paint()
      ..color = qiblaDialArrow
      ..strokeWidth = side * 0.018
      ..strokeCap = StrokeCap.round;
    for (var t = qiblaArrowLength + 0.02; t < qiblaKaabaAt - qiblaKaabaSize / 2.6; t += 0.035) {
      canvas.drawLine(Offset(0, -side * t), Offset(0, -side * (t + 0.012)), dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(QiblaTileDialPainter old) => old.degrees != degrees;
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
                                color: i == 0 && accent != null ? accent : null,
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

/// الإيداعات (طلب المالك): كل إيداع في مستطيل بلون الصناديق، «الاسم الأيام» في سطر، الأقرب أولاً من
/// اليمين؛ عمود حتى ثلاثة وعمودان بعدها (depositColumns). الاسم والأيام بحجم واحد، والأيام كجدول: عمود
/// بعرض أعرضها فتبدأ كلها من موضع واحد. الخانات تصغر بالتساوي، وإن ضاق الارتفاع تصغر الصفوف
/// (fitGrid). مطابقة لـ depositsTile في LamhaWidgetReceiver.kt.
class _DepositsTile extends _Styled {
  const _DepositsTile({required this.items, _Look look = _defaultLook})
    : super(look);

  final List<_ColumnItem> items;

  int get _cols => depositColumns(items.length);
  int get _rows => gridRows(items.length);

  @override
  _DepositsTile withLook(_Look look) => _DepositsTile(items: items, look: look);

  /// مقاسه بالصفوف وحشوات مستطيلاتها.
  @override
  ({double text, double pad}) heights(BuildContext context, double width) => (
    text: _rows * depositSize * tileLineHeight * s,
    pad: _rows * depositPadV * 2 + depositRowGap * (_rows - 1),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cellWidth =
          (c.maxWidth - columnGap * (_cols - 1)) / _cols -
          depositPadH * 2 -
          fitMargin;
      final nameStyle = TextStyle(
        fontSize: depositSize * s,
        fontWeight: FontWeight.w400,
        height: tileLineHeight,
        color: primary,
      );
      final daysStyle = nameStyle.copyWith(
        fontWeight: FontWeight.w500,
        color: secondary,
      );
      double widest(Iterable<String> t, TextStyle st) =>
          t.fold(0.0, (a, x) => math.max(a, _measure(context, x, st)));
      final nameW = widest(items.map((i) => i.name), nameStyle);
      final daysW = look.showSub
          ? widest(items.map((i) => i.sub), daysStyle)
          : 0.0;
      // الفاصل وهامش عمود الأيام وحشوات المستطيلات لا تصغر مع النص، فتُطرح.
      final fixed = look.showSub ? gridDaysGap + gridDaysSlack : 0.0;
      final fit = fitGrid(
        height: c.maxHeight - _rows * depositPadV * 2,
        width: math.max(1.0, cellWidth - fixed),
        line: depositSize * s * tileLineHeight,
        cellWidth: nameW + daysW,
        rows: _rows,
        gap: depositRowGap,
      );
      // عمود الأيام بعرض أعرضها بعد التصغير (+ هامش للتقريب)، والاسم ما بقي.
      final daysColumn = daysW * fit.scale + gridDaysSlack;
      final size = depositSize * s * fit.scale;
      Widget cell(int i) {
        if (i >= items.length) return const SizedBox.shrink();
        final item = items[i];
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(depositRadius),
            color: tileBoxColor,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: depositPadH,
              vertical: depositPadV,
            ),
            child: Row(
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
                    style: nameStyle.copyWith(fontSize: size),
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
                      style: daysStyle.copyWith(fontSize: size),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      return _centered(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var r = 0; r < _rows; r++) ...[
              if (r > 0) const SizedBox(height: depositRowGap),
              Row(
                key: Key('deposit-row-$r'),
                children: [
                  for (var k = 0; k < _cols; k++) ...[
                    if (k > 0) const SizedBox(width: columnGap),
                    Expanded(child: cell(r * _cols + k)),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    },
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
