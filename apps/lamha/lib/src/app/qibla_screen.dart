import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../engine/arabic.dart';
import '../engine/compass.dart';
import '../engine/qibla.dart';
import 'providers.dart';
import 'services.dart';
import 'widget_preview.dart' show kaabaAsset;

/// شاشة «اتجاه القبلة» (تصميم المالك، lamha_qibla_update.md): القرص هو الذي يدور والمؤشر ثابت
/// أعلاه، وعليه خط ذهبي منقّط من الكعبة في المركز باتجاه القبلة. يدير المستخدم الجوال حتى يصل الخط
/// للمؤشر؛ عند فرق ≤ ٣° يخضرّ الإطار والمؤشر والخلفية ويهتز الجوال مرة.
/// تُفتح من مربع القبلة في الودجت (lamha://qibla) أو من زر في الإعدادات.
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  static const routeName = 'qibla';

  /// مدة انتظار أول قراءة قبل اعتبار الحساس غير متوفر.
  static const sensorTimeout = Duration(seconds: 4);

  // ألوان التصميم.
  static const background = Color(0xFF1C2A20);
  static const alignedBackground = Color(0xFF1F3323);
  static const dial = Color(0xFF223326);
  static const card = Color(0xFF24382A);
  static const faintBorder = Color(0xFF3A5240);
  static const ticks = Color(0xFF5F7A63);
  static const text = Color(0xFFECE6D8);
  static const textDim = Color(0xFFA9B5A6);
  static const gold = Color(0xFFEF9F27);
  static const north = Color(0xFFF09595);
  static const alignedColor = Color(0xFF639922);
  static const alignedLight = Color(0xFF97C459);

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

enum _Sensor { waiting, available, unavailable }

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  StreamSubscription<CompassReading>? _sub;
  Timer? _timeout;
  var _sensor = _Sensor.waiting;
  CompassReading? _last;

  /// اتجاه القرص بعد التنعيم (smoothHeading)، فلا يرتجف.
  double? _shown;
  var _aligned = false;

  @override
  void initState() {
    super.initState();
    final stream = ref.read(compassSourceProvider).readings();
    if (stream == null) {
      _sensor = _Sensor.unavailable;
      return;
    }
    _timeout = Timer(QiblaScreen.sensorTimeout, () {
      if (_last == null) setState(() => _sensor = _Sensor.unavailable);
    });
    _sub = stream.listen(
      _onReading,
      onError: (Object e) {
        debugPrint('compass: $e');
        setState(() => _sensor = _Sensor.unavailable);
      },
    );
  }

  void _onReading(CompassReading r) {
    final q =
        ref.read(settingsControllerProvider).value?.schedule['qibla'] as Map?;
    final qibla = (q?['degrees'] as num?)?.toDouble();
    final heading = r.heading;
    // التطابق من القراءة نفسها (فوري)، والقرص من القراءة المنعّمة.
    final aligned =
        qibla != null &&
        heading != null &&
        isAligned(
          qiblaArrowAngle(qibla: qibla, heading: heading),
          wasAligned: _aligned,
        );
    // اهتزاز خفيف مرة واحدة عند الدخول في التطابق، ولا يتكرر حتى يخرج ثم يعود.
    if (aligned && !_aligned) {
      ref.read(vibrationProvider).alignedPulse();
    }
    setState(() {
      _last = r;
      _aligned = aligned;
      if (heading != null) _shown = smoothHeading(_shown, heading);
      _sensor = heading == null ? _Sensor.unavailable : _Sensor.available;
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final app = ref.watch(settingsControllerProvider).value;
    final q = app?.schedule['qibla'] as Map?;
    final qibla = (q?['degrees'] as num?)?.toDouble();
    final digits = app?.settings.digits ?? DigitStyle.arabic;
    final heading = _shown;
    final live = _sensor == _Sensor.available && heading != null;
    final aligned = _aligned && live;
    const textStyle = TextStyle(color: QiblaScreen.text);

    return AnimatedContainer(
      key: const Key('qibla-background'),
      duration: const Duration(milliseconds: 250),
      color: aligned ? QiblaScreen.alignedBackground : QiblaScreen.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: QiblaScreen.text,
          title: Text(l.qiblaTitle),
          actions: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.location_on_outlined),
            ),
          ],
        ),
        body: qibla == null || app == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text(
                    '${app.settings.cityName} · ${q!['direction']}',
                    textAlign: TextAlign.center,
                    style: textStyle.copyWith(
                      color: QiblaScreen.textDim,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    l.qiblaFromNorth(
                      l.degrees(formatDigits(qibla.round(), digits)),
                    ),
                    key: const Key('qibla-angle'),
                    textAlign: TextAlign.center,
                    style: textStyle.copyWith(
                      color: QiblaScreen.textDim,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // اتجاه الجوال الحالي.
                  Text(
                    live
                        ? l.degrees(formatDigits(heading.round() % 360, digits))
                        : '—',
                    key: const Key('qibla-heading'),
                    textAlign: TextAlign.center,
                    style: textStyle.copyWith(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (live) ...[
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.84,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  key: const Key('qibla-compass'),
                                  painter: QiblaDialPainter(
                                    heading: heading,
                                    qibla: qibla,
                                    aligned: aligned,
                                  ),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: 0.24,
                                heightFactor: 0.24,
                                child: Image.asset(
                                  kaabaAsset,
                                  key: const Key('qibla-kaaba'),
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      aligned ? l.qiblaAligned : l.compassHint,
                      key: Key(aligned ? 'qibla-aligned' : 'qibla-hint'),
                      textAlign: TextAlign.center,
                      style: textStyle.copyWith(
                        fontSize: aligned ? 20 : 15,
                        fontWeight: aligned ? FontWeight.w700 : FontWeight.w500,
                        color: aligned
                            ? QiblaScreen.alignedLight
                            : QiblaScreen.text,
                      ),
                    ),
                  ] else if (_sensor == _Sensor.unavailable)
                    _Notice(
                      key: const Key('compass-unavailable'),
                      text: l.compassUnavailable,
                    )
                  else
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(l.compassWaiting, style: textStyle),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          key: const Key('qibla-distance'),
                          title: l.qiblaDistance,
                          value: l.qiblaDistanceKm(
                            formatDigits(
                              distanceToKaabaKm(
                                app.settings.latitude,
                                app.settings.longitude,
                              ).round(),
                              digits,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoCard(
                          key: const Key('qibla-accuracy'),
                          title: l.compassAccuracyTitle,
                          value: live
                              ? l.compassAccuracy(
                                  compassAccuracy(_last?.accuracy).name,
                                )
                              : '—',
                        ),
                      ),
                    ],
                  ),
                  if (live &&
                      compassAccuracy(_last?.accuracy) ==
                          CompassAccuracy.poor) ...[
                    const SizedBox(height: 10),
                    _Notice(
                      key: const Key('compass-calibrate'),
                      text: l.compassCalibrate,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({super.key, required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: QiblaScreen.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: QiblaScreen.faintBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: QiblaScreen.textDim, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: QiblaScreen.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: QiblaScreen.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: QiblaScreen.faintBorder),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: QiblaScreen.textDim),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: QiblaScreen.text)),
        ),
      ],
    ),
  );
}

/// القرص الدوّار: يدور بـ −[heading] فيبقى الشمال في مكانه الحقيقي. تدريج كل ١٠° وأطول كل
/// ٣٠°، وحروف الاتجاهات (ش بالأحمر)، وخط منقّط ذهبي من المركز إلى المحيط عند [qibla]،
/// ومؤشر مثلث ثابت أعلى القرص. [aligned]: الإطار والمؤشر بالأخضر.
class QiblaDialPainter extends CustomPainter {
  QiblaDialPainter({
    required this.heading,
    required this.qibla,
    required this.aligned,
  });

  final double heading;
  final double qibla;
  final bool aligned;

  static const _rad = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 6;
    final r = outer - 16; // القرص تحت المؤشر.

    // الإطار الخارجي.
    canvas.drawCircle(
      c,
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? 4 : 2
        ..color = aligned ? QiblaScreen.alignedColor : QiblaScreen.faintBorder,
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-heading * _rad);

    // القرص.
    canvas.drawCircle(Offset.zero, r, Paint()..color = QiblaScreen.dial);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = QiblaScreen.faintBorder,
    );

    // التدريج.
    for (var d = 0; d < 360; d += 10) {
      final a = d * _rad;
      final dir = Offset(math.sin(a), -math.cos(a));
      final long = d % 30 == 0;
      canvas.drawLine(
        dir * (r - (long ? 16 : 8)),
        dir * (r - 2),
        Paint()
          ..strokeWidth = long ? 2.5 : 1.2
          ..color = QiblaScreen.ticks,
      );
    }

    // حروف الاتجاهات، قائمة دائماً بالنسبة للشاشة.
    for (final (deg, label, color) in [
      (0, 'ش', QiblaScreen.north),
      (90, 'ق', QiblaScreen.text),
      (180, 'ج', QiblaScreen.text),
      (270, 'غ', QiblaScreen.text),
    ]) {
      final a = deg * _rad;
      final p = Offset(math.sin(a), -math.cos(a)) * (r - 36);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          // TextPainter لا يرث خط السمة.
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: color,
            fontSize: r * 0.13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(heading * _rad);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // خط منقّط ذهبي من المركز إلى المحيط باتجاه القبلة (بلا علامة على المحيط: طلب المالك).
    final qa = qibla * _rad;
    final qdir = Offset(math.sin(qa), -math.cos(qa));
    final dash = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = QiblaScreen.gold;
    for (var t = r * 0.18; t < r - 4; t += 10) {
      canvas.drawLine(qdir * t, qdir * math.min(t + 5, r - 4), dash);
    }

    canvas.restore();

    // المؤشر الثابت أعلى القرص.
    final tip = Offset(c.dx, c.dy - r + 2);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - 11, c.dy - outer - 2)
        ..lineTo(tip.dx + 11, c.dy - outer - 2)
        ..close(),
      Paint()..color = aligned ? QiblaScreen.alignedLight : QiblaScreen.text,
    );
  }

  @override
  bool shouldRepaint(QiblaDialPainter old) =>
      old.heading != heading || old.qibla != qibla || old.aligned != aligned;
}
