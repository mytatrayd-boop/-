import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/cafe_repository.dart';
import 'repositories/scan_repository.dart';

/// يُستبدل في main (الجهاز) وفي الاختبارات (قاعدة بالذاكرة).
final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => throw UnimplementedError('scanRepositoryProvider must be overridden'),
);

final cafeRepositoryProvider = Provider<CafeRepository>(
  (ref) => throw UnimplementedError('cafeRepositoryProvider must be overridden'),
);
