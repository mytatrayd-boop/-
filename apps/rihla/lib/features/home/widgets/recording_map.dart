import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/geo/geo_point.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/location/location_source.dart';
import '../../../data/map/map_tiles.dart';
import '../../../l10n/app_localizations.dart';
import '../map_frame_capturer.dart';

/// نص الإسناد الحرفي الذي تشترطه OpenFreeMap وODbL (D15). حرفي عمداً وليس في
/// ARB: نص قانوني لا يُترجم.
const mapAttributionLine1 =
    'OpenFreeMap © OpenMapTiles Data from OpenStreetMap';
const mapAttributionLine2 = '© OpenStreetMap contributors';

/// نسبة لوحة الخريطة في الفيديو (640x720).
const double videoMapAspect = 640 / 720;

/// هامش الإسناد عن حافة الإطار المقصوص (dp).
const double attributionMargin = 4;

/// خريطة التسجيل: ويدجت Flutter خالص (لا platform view) داخل RepaintBoundary
/// فيمكن التقاطها بـtoImage مع الإسناد في كل إطار (ARCHITECTURE 4.1).
/// الإسناد جزء من شجرة الـRepaintBoundary نفسها: لا يُقص ولا يُغطّى.
class RecordingMap extends StatefulWidget {
  const RecordingMap({
    super.key,
    required this.tiles,
    required this.fix,
    required this.track,
    required this.interactive,
    this.boundaryKey,
    this.followZoom = 16,
    this.videoAspect = videoMapAspect,
    this.recenterDelay = const Duration(seconds: 8),
  });

  final MapTilesSource tiles;
  final LocationFix? fix;
  final List<GeoPoint> track;

  /// قبل البدء تسمح الخريطة بالتحريك؛ أثناء التسجيل لا (لتجنب اللمس العرضي).
  final bool interactive;

  /// مفتاح RepaintBoundary لمصدر الالتقاط (F0ب/F6).
  final GlobalKey? boundaryKey;
  final double followZoom;

  /// نسبة (عرض/ارتفاع) لوحة الخريطة في الفيديو؛ يُوضع الإسناد داخل المنطقة
  /// المتبقية بعد القص المركزي إليها.
  final double videoAspect;
  final Duration recenterDelay;

  @override
  State<RecordingMap> createState() => _RecordingMapState();
}

class _RecordingMapState extends State<RecordingMap> {
  final _controller = MapController();
  bool _ready = false;
  bool _following = true;
  Timer? _recenterTimer;

  @override
  void dispose() {
    _recenterTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  LatLng? get _pos =>
      widget.fix == null ? null : LatLng(widget.fix!.lat, widget.fix!.lng);

  @override
  void didUpdateWidget(RecordingMap old) {
    super.didUpdateWidget(old);
    if (_following && widget.fix != old.fix) _moveToFix();
  }

  void _moveToFix() {
    final p = _pos;
    if (p == null || !_ready) return;
    _controller.move(p, widget.followZoom);
  }

  void _onMoved(bool hasGesture) {
    if (!hasGesture || !_following) return;
    setState(() => _following = false);
    _recenterTimer?.cancel();
    _recenterTimer = Timer(widget.recenterDelay, _recenter);
  }

  void _recenter() {
    _recenterTimer?.cancel();
    if (!mounted) return;
    setState(() => _following = true);
    _moveToFix();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pos = _pos;
    return RepaintBoundary(
      key: widget.boundaryKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: pos ?? const LatLng(0, 0),
              initialZoom: pos == null ? 2 : widget.followZoom,
              minZoom: 2,
              maxZoom: 19,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.drag |
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.pinchMove
                    : InteractiveFlag.none,
              ),
              onMapReady: () {
                _ready = true;
                _moveToFix();
              },
              onPositionChanged: (_, hasGesture) => _onMoved(hasGesture),
            ),
            children: [
              widget.tiles.buildLayer(context),
              if (widget.track.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        for (final p in widget.track) LatLng(p.lat, p.lng),
                      ],
                      strokeWidth: 6,
                      color: AppColors.amber,
                      borderStrokeWidth: 2,
                      borderColor: AppColors.ink,
                    ),
                  ],
                ),
              if (pos != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pos,
                      width: 36,
                      height: 36,
                      child: _MyLocationMarker(
                        headingDeg: widget.fix!.headingDeg,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (pos == null)
            Center(
              child: _Pill(
                key: const ValueKey('map-locating'),
                text: l.mapLocating,
              ),
            ),
          // الإسناد داخل الـRepaintBoundary (أسفل يمين اللوحة، تباين عالٍ).
          // الاتجاه ثابت LTR لأن النص إنجليزي والتخطيط لا ينعكس.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (_, c) {
                final r = coverCropRectOf(
                  Size(c.maxWidth, c.maxHeight),
                  widget.videoAspect,
                );
                return Stack(
                  children: [
                    Positioned(
                      right: c.maxWidth - r.right + attributionMargin,
                      bottom: c.maxHeight - r.bottom + attributionMargin,
                      child: MapAttribution(
                        maxWidth: r.width - 2 * attributionMargin,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (!_following)
            Positioned(
              left: 8,
              bottom: 8,
              child: SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(
                  key: const ValueKey('map-recenter'),
                  tooltip: l.mapRecenter,
                  onPressed: _recenter,
                  icon: const Icon(Icons.my_location),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, this.maxWidth});

  /// أقصى عرض؛ النص يلتف على سطرين+ ليبقى كاملاً داخل الإطار المقصوص.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      key: const ValueKey('map-attribution'),
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      color: const Color(0xB3000000),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            mapAttributionLine1,
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 11,
              height: 1.2,
              decoration: TextDecoration.none,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            mapAttributionLine2,
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 11,
              height: 1.2,
              decoration: TextDecoration.none,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MyLocationMarker extends StatelessWidget {
  const _MyLocationMarker({this.headingDeg});
  final double? headingDeg;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.amber,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.ink, width: 3),
    ),
    child: headingDeg == null
        ? null
        : Transform.rotate(
            angle: headingDeg! * math.pi / 180,
            child: const Icon(Icons.navigation, size: 20, color: AppColors.ink),
          ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surface1.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}
