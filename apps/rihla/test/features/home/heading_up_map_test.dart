import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rihla/data/location/location_source.dart';
import 'package:rihla/data/map/map_tiles.dart' show FakeMapTiles;
import 'package:rihla/features/home/map_frame_capturer.dart';
import 'package:rihla/features/home/widgets/recording_map.dart';
import 'package:rihla/l10n/app_localizations.dart';
import 'package:rihla/core/geo/bearing.dart';

LocationFix fix(double lat, double lng, {double? h, double? v}) => LocationFix(
  lat: lat,
  lng: lng,
  headingDeg: h,
  speedMps: v,
  time: DateTime.utc(2026),
);

Widget host(Size size, LocationFix? f, {Key? key, GlobalKey? bk}) =>
    MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: size,
          child: RecordingMap(
            key: key,
            boundaryKey: bk,
            tiles: const FakeMapTiles(),
            fix: f,
            track: const [],
            interactive: false,
          ),
        ),
      ),
    );

MapCamera cameraOf(WidgetTester t) =>
    MapCamera.of(t.element(find.byType(MarkerLayer)));

void main() {
  const size = Size(800, 360);

  testWidgets(
    'heading east: map rotated -90, marker in lower third, arrow up',
    (t) async {
      final bk = GlobalKey();
      await t.pumpWidget(host(size, fix(24.7, 46.7, h: 90, v: 15), bk: bk));
      await t.pump();
      await t.pumpWidget(host(size, fix(24.7, 46.7, h: 90, v: 15), bk: bk));
      await t.pump();
      final cam = cameraOf(t);
      expect(normalizeDegrees(cam.rotation), closeTo(270, 1e-6));

      final crop = coverCropRectOf(size, videoMapAspect);
      final m = t.getCenter(find.byIcon(Icons.navigation));
      expect(m.dx, closeTo(size.width / 2, 1.5));
      expect(m.dy, closeTo(crop.top + markerTopFraction * crop.height, 1.5));
      expect(m.dy, greaterThan(crop.top + 2 / 3 * crop.height));

      // السهم للأعلى: لا دوران صافٍ (الخريطة -90 والعلامة تعاكسها).
      // الدوران الصافي للسهم على الشاشة صفر (الخريطة -90 والعلامة تعاكسها).
      final net = t
          .renderObject(find.byIcon(Icons.navigation))
          .getTransformTo(null);
      expect(net.storage[1].abs(), lessThan(1e-6));
      expect(net.storage[0], greaterThan(0.99));
      // شرقاً (اتجاه السير) يظهر فوق العلامة لا يمينها.
      final me = cam.latLngToScreenPoint(const LatLng(24.7, 46.7));
      final east = cam.latLngToScreenPoint(const LatLng(24.7, 46.7005));
      expect(east.y, lessThan(me.y - 10));
      expect((east.x - me.x).abs(), lessThan(1));
      // نقطة أمام العلامة (شرقاً) تظهر فوقها على الشاشة.
      final ahead = cam.latLngToScreenPoint(cam.center); // المركز أمام العلامة
      expect(ahead.y, closeTo(size.height / 2, 1.5));
    },
  );

  testWidgets('no heading and no movement: north-up, arrow up', (t) async {
    await t.pumpWidget(host(size, fix(24.7, 46.7)));
    await t.pump();
    await t.pumpWidget(host(size, fix(24.7, 46.7)));
    await t.pump();
    expect(cameraOf(t).rotation, closeTo(0, 1e-9));
  });

  testWidgets('stationary keeps the last bearing', (t) async {
    await t.pumpWidget(host(size, fix(24.7, 46.7, h: 180, v: 10)));
    await t.pump();
    await t.pumpWidget(host(size, fix(24.7, 46.7, h: 180, v: 10)));
    await t.pump();
    await t.pumpWidget(host(size, fix(24.7, 46.7, h: 10, v: 0)));
    await t.pump();
    expect(normalizeDegrees(cameraOf(t).rotation), closeTo(180, 1e-6));
  });

  testWidgets('rotated map still covers the frame (overscan) and keeps size', (
    t,
  ) async {
    await t.pumpWidget(host(size, fix(24.7, 46.7, h: 45, v: 10)));
    await t.pump();
    await t.pumpWidget(host(size, fix(24.7, 46.7, h: 45, v: 10)));
    await t.pump();
    final cam = cameraOf(t);
    // حجم رسم الطبقات (مع الدوران) يغطي قطر اللوحة: لا زوايا فارغة.
    expect(cam.size.x, greaterThanOrEqualTo(size.width));
    expect(cam.size.y, greaterThanOrEqualTo(size.height));
    expect(cam.size.x, greaterThan(size.width));
  });

  testWidgets('attribution stays upright and inside crop under rotation', (
    t,
  ) async {
    for (final h in [0.0, 45.0, 90.0, 200.0]) {
      await t.pumpWidget(host(size, fix(24.7, 46.7, h: h, v: 10)));
      await t.pump();
      await t.pumpWidget(host(size, fix(24.7, 46.7, h: h, v: 10)));
      await t.pump();
      final crop = coverCropRectOf(size, videoMapAspect);
      final r = t.getRect(find.byKey(const ValueKey('map-attribution')));
      expect(r.right, lessThanOrEqualTo(crop.right - attributionMargin + .5));
      expect(r.bottom, lessThanOrEqualTo(crop.bottom - attributionMargin + .5));
      expect(r.left, greaterThanOrEqualTo(crop.left));
      expect(r.top, greaterThanOrEqualTo(crop.top));
      // غير مدوَّر: لا Transform.rotate فوق الإسناد.
      final tfs = find.ancestor(
        of: find.byKey(const ValueKey('map-attribution')),
        matching: find.byType(Transform),
      );
      expect(tfs, findsNothing);
    }
  });
}
