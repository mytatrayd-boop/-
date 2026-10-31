import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers.dart';
import '../../domain/cafe.dart';
import 'data/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) => GeolocatorLocationService());

/// يفتح رابطاً خارج التطبيق؛ يُستبدل في الاختبارات.
typedef UrlOpener = Future<bool> Function(Uri uri);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

final cafeSummariesProvider = StreamProvider.autoDispose<List<CafeSummary>>(
  (ref) => ref.watch(cafeRepositoryProvider).watchAll(),
);
