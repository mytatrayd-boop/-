import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../l10n/app_localizations.dart';
import '../engine/arabic.dart';
import '../engine/compass.dart';
import '../engine/qibla.dart';
import 'providers.dart';
import 'services.dart';
import 'widget_preview.dart' show kaabaAsset;

/// شاشة «اتجاه القبلة» بتبويبين (ملاحظات المالك، أكتوبر ٢٠٢٦):
/// - البوصلة: قرص أسود بإطار ذهبي وحلقة خضراء مضيئة (صورة المالك)، يدور بـ −الاتجاه فيبقى
///   الشمال في مكانه، وعليه إبرة خضراء والكعبة على المحيط باتجاه القبلة، ومؤشر ثابت أعلاه.
///   عند فرق ≤ ٣° يخضرّ المؤشر والخلفية ويهتز الجوال مرة.
/// - الخريطة: موقع الجوال وخط إلى الكعبة، مع الاتجاه من الشمال والمسافة.
/// الموقع يُحدَّد تلقائياً عند فتح الشاشة (بلا اختيار يدوي)، وإن تعذّر فالمدينة المحفوظة.
/// تُفتح من مربع القبلة في الودجت (lamha://qibla) أو من زر في الإعدادات.
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  static const routeName = 'qibla';

  /// مدة انتظار أول قراءة قبل اعتبار الحساس غير متوفر.
  static const sensorTimeout = Duration(seconds: 4);

  /// بلاطات الخريطة من OpenStreetMap (تُطفأ في الاختبارات: لا شبكة).
  static var mapTiles = true;

  // ألوان التصميم.
  static const background = Color(0xFF0B1410);
  static const alignedBackground = Color(0xFF0F2A17);
  static const card = Color(0xFF15211A);
  static const faintBorder = Color(0xFF2C3D31);
  static const text = Color(0xFFF2ECDD);
  static const textDim = Color(0xFFA9B5A6);
  static const gold = Color(0xFFD9B45A);
  static const goldLight = Color(0xFFFFE9A8);
  static const goldDeep = Color(0xFF9C7424);
  static const green = Color(0xFF2EE59D);
  static const alignedColor = Color(0xFF3DDC84);
  static const alignedLight = Color(0xFF97E8B4);

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

enum _Sensor { waiting, available, unavailable }

enum _Where { locating, live, saved }

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  StreamSubscription<CompassReading>? _sub;
  Timer? _timeout;
  var _sensor = _Sensor.waiting;
  CompassReading? _last;

  /// اتجاه القرص بعد التنعيم (smoothHeading)، فلا يرتجف.
  double? _shown;
  var _aligned = false;

  var _where = _Where.locating;
  ({double latitude, double longitude})? _pos;

  /// الانحراف المغناطيسي عند الموقع (أندرويد)، يُضاف لقراءة الحساس.
  double _declination = 0;

  @override
  void initState() {
    super.initState();
    _locate();
    final stream = ref.read(compassSourceProvider).readings();
    if (stream == null) {
      _sensor = _Sensor.unavailable;
      return;
    }
    _timeout = Timer(QiblaScreen.sensorTimeout, () {
      if (_last == null && mounted) setState(() => _sensor = _Sensor.unavailable);
    });
    _sub = stream.listen(
      _onReading,
      onError: (Object e) {
        debugPrint('compass: $e');
        if (mounted) setState(() => _sensor = _Sensor.unavailable);
      },
    );
  }

  /// الموقع الحالي تلقائياً؛ وإلا المدينة المحفوظة.
  Future<void> _locate() async {
    ({double latitude, double longitude})? p;
    try {
      p = await ref.read(locationServiceProvider).currentPosition();
    } catch (e) {
      debugPrint('qibla location: $e');
    }
    if (!mounted) return;
    if (p == null) {
      final s = ref.read(settingsControllerProvider).value?.settings;
      setState(() {
        _where = _Where.saved;
        if (s != null) _pos = (latitude: s.latitude, longitude: s.longitude);
      });
    } else {
      setState(() {
        _where = _Where.live;
        _pos = p;
      });
    }
    final at = _pos;
    if (at != null) {
      final d = await ref.read(declinationProvider).at(at.latitude, at.longitude);
      if (mounted) setState(() => _declination = d);
    }
  }

  /// القبلة من الموقع الحالي إن عُرف، وإلا من الجدول (المدينة المحفوظة).
  double? get _qibla {
    if (_where == _Where.live && _pos != null) return qiblaDegrees(_pos!.latitude, _pos!.longitude);
    final q = ref.read(settingsControllerProvider).value?.schedule['qibla'] as Map?;
    return (q?['degrees'] as num?)?.toDouble();
  }

  void _onReading(CompassReading r) {
    final qibla = _qibla;
    final heading = r.heading == null ? null : normalizeDegrees(r.heading! + _declination);
    // التطابق من القراءة نفسها (فوري)، والقرص من القراءة المنعّمة.
    final aligned = qibla != null &&
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
    final qibla = _qibla;
    final digits = app?.settings.digits ?? DigitStyle.arabic;
    final heading = _shown;
    final live = _sensor == _Sensor.available && heading != null;
    final aligned = _aligned && live;
    final pos = _pos ?? (app == null ? null : (latitude: app.settings.latitude, longitude: app.settings.longitude));

    return AnimatedContainer(
      key: const Key('qibla-background'),
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: aligned ? QiblaScreen.alignedBackground : QiblaScreen.background,
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.1,
          colors: aligned
              ? const [Color(0xFF1E4A2B), QiblaScreen.alignedBackground]
              : const [Color(0xFF1B2A20), QiblaScreen.background],
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: QiblaScreen.text,
            title: Text(l.qiblaTitle),
            bottom: TabBar(
              indicatorColor: QiblaScreen.gold,
              labelColor: QiblaScreen.gold,
              unselectedLabelColor: QiblaScreen.textDim,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(key: const Key('qibla-tab-compass'), icon: const Icon(Icons.explore_outlined), text: l.qiblaTabCompass),
                Tab(key: const Key('qibla-tab-map'), icon: const Icon(Icons.map_outlined), text: l.qiblaTabMap),
              ],
            ),
          ),
          body: qibla == null || app == null || pos == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _compass(l, app, qibla, digits, heading, live, aligned, pos),
                    _QiblaMap(
                      position: pos,
                      qibla: qibla,
                      heading: live ? heading : null,
                      digits: digits,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _compass(
    AppLocalizations l,
    AppState app,
    double qibla,
    DigitStyle digits,
    double? heading,
    bool live,
    bool aligned,
    ({double latitude, double longitude}) pos,
  ) {
    const textStyle = TextStyle(color: QiblaScreen.text);
    final place = switch (_where) {
      _Where.locating => l.qiblaLocating,
      _Where.live => l.qiblaMyLocation,
      _Where.saved => app.settings.cityName,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _where == _Where.live ? Icons.my_location : Icons.location_on_outlined,
              size: 16,
              color: QiblaScreen.textDim,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$place · ${directionName(qibla)}',
                key: const Key('qibla-place'),
                textAlign: TextAlign.center,
                style: textStyle.copyWith(color: QiblaScreen.textDim, fontSize: 14),
              ),
            ),
          ],
        ),
        Text(
          l.qiblaFromNorth(l.degrees(formatDigits(qibla.round(), digits))),
          key: const Key('qibla-angle'),
          textAlign: TextAlign.center,
          style: textStyle.copyWith(color: QiblaScreen.textDim, fontSize: 13),
        ),
        const SizedBox(height: 8),
        // اتجاه الجوال الحالي.
        Text(
          live ? l.degrees(formatDigits(heading!.round() % 360, digits)) : '—',
          key: const Key('qibla-heading'),
          textAlign: TextAlign.center,
          style: textStyle.copyWith(fontSize: 44, fontWeight: FontWeight.w700, height: 1.1),
        ),
        const SizedBox(height: 12),
        if (live) ...[
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final side = c.maxWidth;
                    // الكعبة على المحيط الداخلي باتجاه القبلة، وتدور مع القرص.
                    final a = (qibla - heading!) * math.pi / 180;
                    final r = side / 2 * QiblaDialPainter.kaabaRing;
                    final k = side * 0.15;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            key: const Key('qibla-compass'),
                            painter: QiblaDialPainter(heading: heading, qibla: qibla, aligned: aligned),
                          ),
                        ),
                        Positioned(
                          left: side / 2 + math.sin(a) * r - k / 2,
                          top: side / 2 - math.cos(a) * r - k / 2,
                          width: k,
                          height: k,
                          child: Container(
                            padding: EdgeInsets.all(k * 0.16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                              border: Border.all(color: aligned ? QiblaScreen.alignedColor : QiblaScreen.green, width: 2),
                              boxShadow: [
                                BoxShadow(color: QiblaScreen.green.withValues(alpha: aligned ? .8 : .45), blurRadius: aligned ? 16 : 9),
                              ],
                            ),
                            child: Image.asset(kaabaAsset, key: const Key('qibla-kaaba'), filterQuality: FilterQuality.medium),
                          ),
                        ),
                      ],
                    );
                  },
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
              color: aligned ? QiblaScreen.alignedLight : QiblaScreen.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.qiblaHoldFlat,
            textAlign: TextAlign.center,
            style: textStyle.copyWith(fontSize: 13, color: QiblaScreen.textDim),
          ),
        ] else if (_sensor == _Sensor.unavailable)
          _Notice(key: const Key('compass-unavailable'), text: l.compassUnavailable)
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
                value: l.qiblaDistanceKm(formatDigits(distanceToKaabaKm(pos.latitude, pos.longitude).round(), digits)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoCard(
                key: const Key('qibla-accuracy'),
                title: l.compassAccuracyTitle,
                value: live ? l.compassAccuracy(compassAccuracy(_last?.accuracy).name) : '—',
              ),
            ),
          ],
        ),
        if (_where == _Where.saved) ...[
          const SizedBox(height: 10),
          _Notice(key: const Key('qibla-saved-location'), text: l.qiblaSavedLocation(app.settings.cityName)),
        ],
        if (live && compassAccuracy(_last?.accuracy) == CompassAccuracy.poor) ...[
          const SizedBox(height: 10),
          _Notice(key: const Key('compass-calibrate'), text: l.compassCalibrate),
        ],
      ],
    );
  }
}

/// تبويب الخريطة: موقع الجوال، وخط الدائرة العظمى إلى الكعبة، ومخروط اتجاه الجوال إن توفرت
/// البوصلة. تحتها الاتجاه من الشمال والمسافة.
class _QiblaMap extends StatefulWidget {
  const _QiblaMap({required this.position, required this.qibla, required this.heading, required this.digits});

  final ({double latitude, double longitude}) position;
  final double qibla;
  final double? heading;
  final DigitStyle digits;

  @override
  State<_QiblaMap> createState() => _QiblaMapState();
}

class _QiblaMapState extends State<_QiblaMap> {
  final _map = MapController();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = LatLng(widget.position.latitude, widget.position.longitude);
    const kaaba = LatLng(kaabaLatitude, kaabaLongitude);
    final km = distanceToKaabaKm(me.latitude, me.longitude);
    // الخط: نقاط على الدائرة العظمى (يبدو مستقيماً قرب الموقع كما في الصورة المرجعية).
    final line = <LatLng>[for (var i = 0; i <= 64; i++) greatCirclePoint(me, kaaba, i / 64)];
    final degrees = widget.qibla.toStringAsFixed(2);
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              key: const Key('qibla-map'),
              mapController: _map,
              options: MapOptions(
                initialCenter: me,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                if (QiblaScreen.mapTiles)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'sa.lamha.lamha',
                  )
                else
                  const ColoredBox(color: Color(0xFFE9E5DC)),
                PolylineLayer(
                  polylines: [
                    Polyline(points: line, strokeWidth: 5, color: const Color(0xFF1E6FD9)),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: kaaba,
                      width: 44,
                      height: 44,
                      child: Image.asset(kaabaAsset, filterQuality: FilterQuality.medium),
                    ),
                    Marker(
                      point: me,
                      width: 120,
                      height: 120,
                      child: CustomPaint(painter: _MeMarkerPainter(heading: widget.heading, qibla: widget.qibla)),
                    ),
                  ],
                ),
                const SimpleAttributionWidget(source: Text('OpenStreetMap')),
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: QiblaScreen.gold.withValues(alpha: .6)),
          ),
          child: Text(
            l.qiblaHoldFlat,
            textAlign: TextAlign.center,
            style: const TextStyle(color: QiblaScreen.text, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _InfoCard(
                  key: const Key('qibla-map-direction'),
                  title: l.qiblaMapDirection,
                  value: '${formatDigitsText(degrees, widget.digits)}°',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoCard(
                  key: const Key('qibla-map-distance'),
                  title: l.qiblaMapDistance,
                  value: l.qiblaDistanceKm(formatDigits(km.round(), widget.digits)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// نقطة على الدائرة العظمى بين [a] و[b] عند الكسر [f] (٠ = a، ١ = b).
LatLng greatCirclePoint(LatLng a, LatLng b, double f) {
  const r = math.pi / 180;
  final p1 = a.latitude * r, l1 = a.longitude * r, p2 = b.latitude * r, l2 = b.longitude * r;
  final d = 2 *
      math.asin(math.sqrt(math.pow(math.sin((p2 - p1) / 2), 2) + math.cos(p1) * math.cos(p2) * math.pow(math.sin((l2 - l1) / 2), 2)));
  if (d == 0) return a;
  final s1 = math.sin((1 - f) * d) / math.sin(d), s2 = math.sin(f * d) / math.sin(d);
  final x = s1 * math.cos(p1) * math.cos(l1) + s2 * math.cos(p2) * math.cos(l2);
  final y = s1 * math.cos(p1) * math.sin(l1) + s2 * math.cos(p2) * math.sin(l2);
  final z = s1 * math.sin(p1) + s2 * math.sin(p2);
  return LatLng(math.atan2(z, math.sqrt(x * x + y * y)) / r, math.atan2(y, x) / r);
}

/// أرقام نص فيه فاصلة عشرية (مثل ٣٢٤٫٤٦) بشكل الأرقام المختار.
String formatDigitsText(String text, DigitStyle digits) {
  if (digits == DigitStyle.latin) return text;
  const ar = '٠١٢٣٤٥٦٧٨٩';
  return text.split('').map((ch) {
    final i = '0123456789'.indexOf(ch);
    if (i >= 0) return ar[i];
    return ch == '.' ? '٫' : ch;
  }).join();
}

/// موقع الجوال: نقطة زرقاء، ومخروط باتجاه القبلة، ومخروط أزرق فاتح باتجاه الجوال إن توفرت البوصلة.
class _MeMarkerPainter extends CustomPainter {
  _MeMarkerPainter({required this.heading, required this.qibla});

  final double? heading;
  final double qibla;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    void cone(double deg, Color color) {
      final a = (deg - 90) * math.pi / 180;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..arcTo(Rect.fromCircle(center: c, radius: r), a - 0.3, 0.6, false)
          ..close(),
        Paint()..color = color,
      );
    }

    if (heading != null) cone(heading!, const Color(0x5533B5E5));
    cone(qibla, const Color(0x40FF8A00));
    canvas.drawCircle(c, 11, Paint()..color = Colors.white);
    canvas.drawCircle(c, 8, Paint()..color = const Color(0xFF1E6FD9));
  }

  @override
  bool shouldRepaint(_MeMarkerPainter old) => old.heading != heading || old.qibla != qibla;
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
            Text(title, style: const TextStyle(color: QiblaScreen.textDim, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: QiblaScreen.text, fontSize: 18, fontWeight: FontWeight.w700)),
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
            Expanded(child: Text(text, style: const TextStyle(color: QiblaScreen.text))),
          ],
        ),
      );
}

/// القرص الدوّار بتصميم صورة المالك: إطار ذهبي مزدوج، وقرص أسود، وحلقة خضراء مضيئة، وتدريج
/// كل ٥° (أطول كل ٣٠°)، وحروف N وE وS وW الذهبية قائمة دائماً، ونجمة ذهبية في الوسط، وإبرة خضراء
/// من المركز باتجاه [qibla]. يدور بـ −[heading] فيبقى الشمال في مكانه الحقيقي، ومؤشر ثابت أعلاه.
/// الكعبة ودائرتها فوق القرص في الشاشة نفسها (على المحيط [kaabaRing]). [aligned]: كله أخضر أوضح.
class QiblaDialPainter extends CustomPainter {
  QiblaDialPainter({required this.heading, required this.qibla, required this.aligned});

  final double heading;
  final double qibla;
  final bool aligned;

  /// بعد مركز الكعبة عن مركز القرص (نسبة من نصف الضلع).
  static const kaabaRing = 0.6;

  static const _rad = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final half = size.shortestSide / 2;
    final outer = half - 14; // يترك مكان المؤشر الثابت.
    final ringW = outer * 0.07;
    final disc = outer - ringW;
    final green = aligned ? QiblaScreen.alignedColor : QiblaScreen.green;

    // ظل خلف القرص.
    canvas.drawCircle(c, outer, Paint()
      ..color = Colors.black.withValues(alpha: .6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

    // الإطار الذهبي (تدرج دائري يلمع).
    final ringRect = Rect.fromCircle(center: c, radius: outer);
    canvas.drawCircle(
      c,
      outer - ringW / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringW
        ..shader = const SweepGradient(
          colors: [QiblaScreen.goldDeep, QiblaScreen.goldLight, QiblaScreen.gold, QiblaScreen.goldDeep, QiblaScreen.goldLight, QiblaScreen.goldDeep],
        ).createShader(ringRect),
    );

    // القرص الأسود.
    canvas.drawCircle(
      c,
      disc,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF1C1C1C), Color(0xFF050505)]).createShader(Rect.fromCircle(center: c, radius: disc)),
    );
    // خط ذهبي رفيع داخل الإطار.
    canvas.drawCircle(c, disc - 1, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = QiblaScreen.goldDeep);

    // الحلقة الخضراء المضيئة.
    final glowR = disc * 0.86;
    canvas.drawCircle(c, glowR, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = aligned ? 7 : 5
      ..color = green.withValues(alpha: .55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(c, glowR, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = green);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-heading * _rad);

    // التدريج بين الإطار والحلقة.
    for (var d = 0; d < 360; d += 5) {
      final a = d * _rad;
      final dir = Offset(math.sin(a), -math.cos(a));
      final long = d % 30 == 0;
      if (d % 90 == 0) continue; // مكان الحروف.
      canvas.drawLine(
        dir * (disc - (long ? disc * 0.09 : disc * 0.05)),
        dir * (disc - disc * 0.015),
        Paint()
          ..strokeWidth = long ? 2.4 : 1.2
          ..strokeCap = StrokeCap.round
          ..color = long ? QiblaScreen.gold : const Color(0xFFDDDDDD),
      );
    }
    // خطوط ذهبية قصيرة عند الجهات الأربع، خارج الحروف.
    for (var d = 0; d < 360; d += 90) {
      final a = d * _rad;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(dir * (disc * 0.99), dir * (disc * 0.9), Paint()
        ..strokeWidth = 3
        ..color = QiblaScreen.gold);
    }

    // حروف الجهات، قائمة دائماً بالنسبة للشاشة.
    for (final (deg, label) in [(0, 'N'), (90, 'E'), (180, 'S'), (270, 'W')]) {
      final a = deg * _rad;
      final p = Offset(math.sin(a), -math.cos(a)) * (disc * 0.74);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: QiblaScreen.gold,
            fontSize: disc * 0.17,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(heading * _rad);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // النجمة الذهبية (ثماني رؤوس: الطويلة للجهات الأربع).
    for (var i = 0; i < 8; i++) {
      final a = i * 45 * _rad;
      final len = disc * (i.isEven ? 0.5 : 0.3);
      final w = disc * (i.isEven ? 0.07 : 0.05);
      final tip = Offset(math.sin(a), -math.cos(a)) * len;
      final side = Offset(math.cos(a), math.sin(a)) * w;
      canvas.drawPath(Path()..moveTo(0, 0)..lineTo(side.dx, side.dy)..lineTo(tip.dx, tip.dy)..close(),
          Paint()..color = QiblaScreen.goldDeep.withValues(alpha: .9));
      canvas.drawPath(Path()..moveTo(0, 0)..lineTo(-side.dx, -side.dy)..lineTo(tip.dx, tip.dy)..close(),
          Paint()..color = QiblaScreen.gold.withValues(alpha: .9));
    }
    canvas.drawCircle(Offset.zero, disc * 0.2, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = QiblaScreen.goldDeep);

    // الإبرة الخضراء باتجاه القبلة.
    canvas.save();
    canvas.rotate(qibla * _rad);
    final tipY = -disc * (kaabaRing - 0.09);
    final needle = Path()
      ..moveTo(0, tipY)
      ..lineTo(disc * 0.08, -disc * 0.05)
      ..lineTo(0, disc * 0.22)
      ..lineTo(-disc * 0.08, -disc * 0.05)
      ..close();
    canvas.drawPath(needle, Paint()
      ..color = green.withValues(alpha: .6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawPath(
      needle,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [const Color(0xFF0E8F5A), green, const Color(0xFF9CFFD5)],
        ).createShader(Rect.fromLTRB(-disc * 0.08, tipY, disc * 0.08, disc * 0.22)),
    );
    canvas.restore();

    canvas.restore();

    // المحور الذهبي في الوسط.
    canvas.drawCircle(c, disc * 0.06, Paint()
      ..shader = const RadialGradient(colors: [QiblaScreen.goldLight, QiblaScreen.goldDeep]).createShader(Rect.fromCircle(center: c, radius: disc * 0.06)));
    canvas.drawCircle(c, disc * 0.025, Paint()..color = const Color(0xFF3A2A0A));

    // المؤشر الثابت أعلى القرص.
    final top = c.dy - outer;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, top + ringW * 1.4)
        ..lineTo(c.dx - 11, top - 12)
        ..lineTo(c.dx + 11, top - 12)
        ..close(),
      Paint()..color = aligned ? QiblaScreen.alignedLight : QiblaScreen.goldLight,
    );
  }

  @override
  bool shouldRepaint(QiblaDialPainter old) => old.heading != heading || old.qibla != qibla || old.aligned != aligned;
}
