import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/ports/auth_service.dart';

/// حالة الحساب الحالية للواجهة.
final authStatusProvider = NotifierProvider<AuthStatusNotifier, AuthStatus>(AuthStatusNotifier.new);

class AuthStatusNotifier extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    final service = ref.watch(authServiceProvider);
    final sub = service.statusChanges.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return service.status;
  }
}
