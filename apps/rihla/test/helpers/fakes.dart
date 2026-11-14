import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:rihla/data/camera/fake_camera_preview_source.dart';
import 'package:rihla/data/location/fake_location_source.dart';
import 'package:rihla/data/map/map_tiles.dart';
import 'package:rihla/data/network/fake_network_status_source.dart';
import 'package:rihla/data/permissions/fake_permission_service.dart';
import 'package:rihla/data/permissions/permission_service.dart';
import 'package:rihla/data/platform/screen_awake.dart';
import 'package:rihla/features/home/home_controller.dart';
import 'package:rihla/features/onboarding_permissions/permissions_controller.dart';

/// كل اعتمادات الجهاز مزيّفة: لا كاميرا ولا GPS ولا شبكة ولا بلاطات.
class HomeFakes {
  HomeFakes({
    FakePermissionService? permissions,
    FakeCameraPreviewSource? camera,
    FakeLocationSource? location,
    FakeNetworkStatusSource? network,
    FakeScreenAwake? awake,
  }) : permissions =
           permissions ??
           FakePermissionService(
             initial: {
               AppPermission.camera: AppPermissionStatus.granted,
               AppPermission.location: AppPermissionStatus.granted,
               AppPermission.microphone: AppPermissionStatus.granted,
             },
           ),
       camera = camera ?? FakeCameraPreviewSource(),
       location = location ?? FakeLocationSource(),
       network = network ?? FakeNetworkStatusSource(),
       awake = awake ?? FakeScreenAwake();

  final FakePermissionService permissions;
  final FakeCameraPreviewSource camera;
  final FakeLocationSource location;
  final FakeNetworkStatusSource network;
  final FakeScreenAwake awake;

  List<Override> get overrides => [
    permissionServiceProvider.overrideWithValue(permissions),
    cameraPreviewSourceProvider.overrideWithValue(camera),
    locationSourceProvider.overrideWithValue(location),
    networkStatusSourceProvider.overrideWithValue(network),
    screenAwakeProvider.overrideWithValue(awake),
    mapTilesProvider.overrideWithValue(const FakeMapTiles()),
  ];
}
