import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/scan_repository.dart';

/// يُستبدل في main (الجهاز) وفي الاختبارات (قاعدة بالذاكرة).
final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => throw UnimplementedError('scanRepositoryProvider must be overridden'),
);
