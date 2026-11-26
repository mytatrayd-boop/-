import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models/youtube_content.dart';
import '../../domain/ports/auth_service.dart';
import '../login/auth_status_provider.dart';

/// اسم قناة المستخدم للإعدادات (`channels.list?mine=true`، وحدة، كاش 24 ساعة).
/// null دون جلسة أو دون قناة.
final myChannelTitleProvider = FutureProvider.autoDispose<String?>((ref) async {
  if (ref.watch(authStatusProvider) != AuthStatus.signedIn) return null;
  return ref.watch(youTubeApiProvider).myChannelTitle();
});

/// تقدير الحصة لليوم. يُعاد حسابه عند فتح الإعدادات.
final quotaTodayProvider = FutureProvider.autoDispose<QuotaUsage>(
  (ref) => ref.watch(youTubeApiProvider).quotaToday(),
);
