import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:rihla/data/db/app_database.dart';
import 'package:rihla/data/repositories/trip_repository.dart';
import 'package:rihla_recorder/rihla_recorder.dart';
import 'package:rihla/data/camera/fake_camera_preview_source.dart';
import 'package:rihla/data/gallery/video_gallery_service.dart';
import 'package:rihla/data/location/fake_location_source.dart';
import 'package:rihla/data/map/map_tiles.dart';
import 'package:rihla/data/network/fake_network_status_source.dart';
import 'package:rihla/data/permissions/fake_permission_service.dart';
import 'package:rihla/data/permissions/permission_service.dart';
import 'package:rihla/data/platform/screen_awake.dart';
import 'package:rihla/features/home/home_controller.dart';
import 'package:rihla/features/onboarding_permissions/permissions_controller.dart';

/// كل اعتمادات الجهاز مزيّفة: لا كاميرا ولا GPS ولا شبكة ولا بلاطات.
/// يُستدعى مرة لإسكات تحذير drift عند إنشاء قاعدة ذاكرة لكل اختبار.
bool _quiet() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return true;
}

class HomeFakes {
  HomeFakes({
    FakePermissionService? permissions,
    FakeCameraPreviewSource? camera,
    FakeLocationSource? location,
    FakeNetworkStatusSource? network,
    FakeScreenAwake? awake,
    FakeRihlaRecorder? recorder,
    FakeVideoGalleryService? gallery,
    TripRepository Function(AppDatabase)? repoBuilder,
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
       awake = awake ?? FakeScreenAwake(),
       recorder = recorder ?? (FakeRihlaRecorder()..cameraOpen = true),
       gallery = gallery ?? FakeVideoGalleryService(),
       _repoBuilder = repoBuilder,
       db = _quiet() ? AppDatabase(NativeDatabase.memory()) : throw StateError('x');

  final FakePermissionService permissions;
  final FakeCameraPreviewSource camera;
  final FakeLocationSource location;
  final FakeNetworkStatusSource network;
  final FakeScreenAwake awake;
  final FakeRihlaRecorder recorder;
  final FakeVideoGalleryService gallery;
  // ignore: prefer_initializing_formals
  final TripRepository Function(AppDatabase)? _repoBuilder;
  final AppDatabase db;
  late final TripRepository repo = (_repoBuilder ?? TripRepository.new)(db);

  List<Override> get overrides => [
    permissionServiceProvider.overrideWithValue(permissions),
    cameraPreviewSourceProvider.overrideWithValue(camera),
    locationSourceProvider.overrideWithValue(location),
    networkStatusSourceProvider.overrideWithValue(network),
    screenAwakeProvider.overrideWithValue(awake),
    recorderProvider.overrideWithValue(recorder),
    tripRepositoryProvider.overrideWithValue(repo),
    videoGalleryProvider.overrideWithValue(gallery),
    mapTilesProvider.overrideWithValue(const FakeMapTiles()),
  ];
}
