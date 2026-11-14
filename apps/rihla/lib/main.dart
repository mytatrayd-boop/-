import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'data/db/open_database.dart';
import 'data/repositories/trip_repository.dart';
import 'features/onboarding_permissions/permissions_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // طولي افتراضياً؛ شاشة التسجيل وحدها تفرض الأفقي عند الدخول وتعيده عند الخروج.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  final db = await openAppDatabase();
  // رحلات بقيت recording بسبب إغلاق مفاجئ تُعلَّم interrupted.
  final repo = TripRepository(db);
  await repo.markInterruptedTrips();

  // فحص الأذونات عند الإقلاع: النقص يحوّل إلى /permissions.
  final probe = ProviderContainer();
  await probe.read(permissionsProvider.notifier).refresh();
  final start = initialLocationFor(probe.read(permissionsProvider));
  probe.dispose();
  runApp(
    UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          initialLocationProvider.overrideWithValue(start),
          tripRepositoryProvider.overrideWithValue(repo),
        ],
      ),
      child: const RihlaApp(),
    ),
  );
}
