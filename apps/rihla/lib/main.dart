import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/open_database.dart';
import 'data/repositories/trip_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  // رحلات بقيت recording بسبب إغلاق مفاجئ تُعلَّم interrupted.
  await TripRepository(db).markInterruptedTrips();
  runApp(const ProviderScope(child: RihlaApp()));
}
