import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/backend.dart';
import '../backend/demo_backend.dart';
import '../core/models.dart';

/// Creates the real backend, or null when Firebase isn't configured (demo-only build).
typedef RealBackendFactory = Backend? Function();

final realBackendFactoryProvider = Provider<RealBackendFactory>((ref) => () => null);
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// The active backend: the real one, or the on-device demo while trying the app.
class BackendNotifier extends Notifier<Backend> {
  Backend? _real;

  @override
  Backend build() {
    _real = ref.read(realBackendFactoryProvider)();
    return _real ?? DemoBackend(seeded: false);
  }

  bool get hasReal => _real != null;

  /// "تجربة سريعة بأسرة جاهزة": switch to a seeded local family.
  void startDemo() {
    if (state.isDemo) state.dispose();
    state = DemoBackend();
  }

  /// Leaving the demo returns to the real backend (if configured).
  Future<void> signOut() async {
    await state.signOut();
    if (state.isDemo && _real != null) {
      state.dispose();
      state = _real!;
    }
  }
}

final backendProvider = NotifierProvider<BackendNotifier, Backend>(BackendNotifier.new);

final appStateProvider = StreamProvider<AppState>((ref) => ref.watch(backendProvider).states);

/// Ticks every second, for competition countdowns and relative times.
final clockProvider = StreamProvider<DateTime>((ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()));

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'themeMode';
  @override
  ThemeMode build() {
    final v = ref.read(prefsProvider).getString(_key);
    return ThemeMode.values.where((m) => m.name == v).firstOrNull ?? ThemeMode.system;
  }

  void set(ThemeMode m) {
    state = m;
    ref.read(prefsProvider).setString(_key, m.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// The last 3 feedback messages sent from this device (shown under the form).
class FeedbackHistory extends Notifier<List<SentFeedback>> {
  static const _key = 'feedbackHistory';
  @override
  List<SentFeedback> build() {
    try {
      final raw = ref.read(prefsProvider).getString(_key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((e) => SentFeedback(e['type'] as String, e['text'] as String, DateTime.parse(e['at'] as String)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void add(SentFeedback f) {
    state = [f, ...state].take(3).toList();
    ref.read(prefsProvider).setString(
        _key, jsonEncode([for (final x in state) {'type': x.type, 'text': x.text, 'at': x.at.toIso8601String()}]));
  }
}

final feedbackHistoryProvider = NotifierProvider<FeedbackHistory, List<SentFeedback>>(FeedbackHistory.new);
