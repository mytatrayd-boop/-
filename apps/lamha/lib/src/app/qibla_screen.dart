import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../engine/arabic.dart';
import '../engine/compass.dart';
import 'providers.dart';
import 'services.dart';

/// شاشة «اتجاه القبلة»: بوصلة حية من حساس الجهاز وسهم يشير إلى القبلة.
/// تُفتح من مربع القبلة في الودجت (lamha://qibla) أو من زر في الإعدادات.
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  static const routeName = 'qibla';

  /// مدة انتظار أول قراءة قبل اعتبار الحساس غير متوفر.
  static const sensorTimeout = Duration(seconds: 4);

  /// لون الشاشة والسهم حين يتجه الجهاز إلى القبلة.
  static const alignedColor = Color(0xFF2E9E5B);

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

enum _Sensor { waiting, available, unavailable }

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  StreamSubscription<CompassReading>? _sub;
  Timer? _timeout;
  var _sensor = _Sensor.waiting;
  CompassReading? _last;
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
    final aligned =
        qibla != null &&
        heading != null &&
        isAligned(
          qiblaArrowAngle(qibla: qibla, heading: heading),
          wasAligned: _aligned,
        );
    // عند الوصول إلى القبلة فقط: نبضتان قويتان (لا اهتزاز مستمر).
    if (aligned && !_aligned) {
      ref.read(vibrationProvider).alignedPulse();
    }
    setState(() {
      _last = r;
      _aligned = aligned;
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
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;
    final app = ref.watch(settingsControllerProvider).value;
    final q = app?.schedule['qibla'] as Map?;
    final qibla = (q?['degrees'] as num?)?.toDouble();
    final heading = _last?.heading;
    final aligned = _aligned && _sensor == _Sensor.available;

    return Scaffold(
      appBar: AppBar(title: Text(l.qiblaTitle)),
      body: AnimatedContainer(
        key: const Key('qibla-background'),
        duration: const Duration(milliseconds: 250),
        color: aligned
            ? QiblaScreen.alignedColor.withValues(alpha: 0.25)
            : Colors.transparent,
        child: qibla == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    l.qiblaFromNorth(
                      l.degrees(
                        formatDigits(qibla.round(), app!.settings.digits),
                      ),
                    ),
                    key: const Key('qibla-angle'),
                    textAlign: TextAlign.right,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${q!['direction']} · ${app.settings.cityName}',
                    textAlign: TextAlign.right,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (_sensor == _Sensor.available && heading != null) ...[
                    AspectRatio(
                      aspectRatio: 1,
                      child: CustomPaint(
                        key: const Key('qibla-compass'),
                        painter: QiblaCompassPainter(
                          heading: heading,
                          arrow: qiblaArrowAngle(
                            qibla: qibla,
                            heading: heading,
                          ),
                          accent: aligned ? QiblaScreen.alignedColor : accent,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (aligned)
                      Row(
                        key: const Key('qibla-aligned'),
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: QiblaScreen.alignedColor,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.qiblaAligned,
                              textAlign: TextAlign.right,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: QiblaScreen.alignedColor,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        l.compassHint,
                        textAlign: TextAlign.right,
                        style: textTheme.bodyMedium,
                      ),
                    if (needsCalibration(_last?.accuracy)) ...[
                      const SizedBox(height: 12),
                      _Notice(
                        key: const Key('compass-calibrate'),
                        text: l.compassCalibrate,
                      ),
                    ],
                  ] else if (_sensor == _Sensor.unavailable)
                    _Notice(
                      key: const Key('compass-unavailable'),
                      text: l.compassUnavailable,
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(l.compassWaiting),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(text, textAlign: TextAlign.right)),
        ],
      ),
    ),
  );
}

/// قرص يدور مع الجهاز (الشمال في مكانه الحقيقي)، وسهم القبلة بزاوية [arrow] من أعلى الجهاز.
class QiblaCompassPainter extends CustomPainter {
  QiblaCompassPainter({
    required this.heading,
    required this.arrow,
    required this.accent,
    required this.color,
  });

  final double heading;
  final double arrow;
  final Color accent;
  final Color color;

  static const _rad = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.5);
    canvas.drawCircle(c, r, ring);

    // علامات القرص كل ٣٠°، والشمال بلون أحمر، كلها مُدارة بعكس اتجاه الجهاز.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-heading * _rad);
    for (var d = 0; d < 360; d += 30) {
      final a = d * _rad;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
        dir * (r - (d == 0 ? 18 : 10)),
        dir * r,
        Paint()
          ..strokeWidth = d == 0 ? 4 : 2
          ..color = d == 0
              ? const Color(0xFFE05A47)
              : color.withValues(alpha: 0.6),
      );
    }
    canvas.restore();

    // سهم القبلة.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(arrow * _rad);
    final s = r / 100;
    canvas.drawPath(
      Path()
        ..moveTo(0, -80 * s)
        ..lineTo(18 * s, 0)
        ..lineTo(0, -12 * s)
        ..lineTo(-18 * s, 0)
        ..close(),
      Paint()..color = accent,
    );
    canvas.drawCircle(Offset.zero, 6 * s, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(QiblaCompassPainter old) =>
      old.heading != heading || old.arrow != arrow || old.accent != accent;
}
