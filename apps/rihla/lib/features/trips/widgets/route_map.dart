import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/geo/geo_point.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/home_controller.dart';
import '../../home/widgets/recording_map.dart';

/// خريطة مسار كاملة بلا تفاعل: تُضبط الكاميرا على حدود المسار كله فلا يُقص
/// منه شيء (بداية خضراء ونهاية حمراء وإسناد الخريطة).
class RouteMap extends ConsumerWidget {
  const RouteMap({super.key, required this.points});
  final List<GeoPoint> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ll = [for (final p in points) LatLng(p.lat, p.lng)];
    final fit = ll.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(ll),
            padding: const EdgeInsets.all(32),
            maxZoom: 17,
          )
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: ll.isEmpty ? const LatLng(0, 0) : ll.first,
            initialZoom: ll.isEmpty ? 2 : 16,
            initialCameraFit: fit,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            ref.watch(mapTilesProvider).buildLayer(context),
            if (ll.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: ll,
                    strokeWidth: 6,
                    color: AppColors.amber,
                    borderStrokeWidth: 2,
                    borderColor: AppColors.ink,
                  ),
                ],
              ),
            if (ll.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: ll.first,
                    width: 20,
                    height: 20,
                    child: const _Dot(AppColors.emerald),
                  ),
                  if (ll.length >= 2)
                    Marker(
                      point: ll.last,
                      width: 20,
                      height: 20,
                      child: const _Dot(AppColors.recordRed),
                    ),
                ],
              ),
          ],
        ),
        const Positioned(right: 0, bottom: 0, child: MapAttribution()),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
  );
}
