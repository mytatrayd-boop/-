import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../core/logic.dart';
import '../core/models.dart';

class AppError implements Exception {
  AppError(this.code, [this.details = const {}]);
  final String code;
  final Map<String, dynamic> details;
  @override
  String toString() => 'AppError($code)';
}

class AppState {
  const AppState({this.session, this.data, this.loading = false});
  final Session? session;
  final FamilySnapshot? data;
  final bool loading;

  Person? get me => session == null ? null : data?.person(session!.personId);
  bool get signedIn => session != null && data != null && me != null;
}

class VerifyResult {
  VerifyResult({required this.first, required this.familyName, required this.name});
  final bool first;
  final String familyName;
  final String name;
}

/// Everything the UI can ask of the backend. Two implementations:
/// [FirebaseBackend] (real, server-validated) and [DemoBackend] (local, on-device
/// trial with a ready-made family, mirroring the prototype).
abstract class Backend {
  bool get isDemo;

  final _ctrl = StreamController<AppState>.broadcast();
  AppState _state = const AppState();
  AppState get current => _state;

  Stream<AppState> get states async* {
    yield _state;
    yield* _ctrl.stream;
  }

  @protected
  void emit(AppState s) {
    _state = s;
    _ctrl.add(s);
  }

  /// Local demo mailbox (empty for the real backend).
  List<DemoMail> get outbox => const [];

  // ---- auth
  /// Returns false when a still-valid code was already sent (not re-sent).
  /// With [password], verifying the code also sets it (sign-up or reset).
  Future<bool> requestCode({required String email, required Role role, String? familyName, String? name, String? password, bool resend = false});
  Future<VerifyResult> verifyCode({required String email, required String code});
  Future<VerifyResult> login({required String email, required String password});
  Future<void> signOut();

  // ---- people
  Future<void> addPerson({required Role role, required String name, required String email, required String avatar, Map<Perm, bool>? perms});
  Future<void> resendInvite(String personId);
  Future<void> updatePerms(String personId, Map<Perm, bool> perms);
  Future<void> removePerson(String personId);
  /// [photo] (JPEG bytes) goes with avatar "photo".
  Future<void> setAvatar(String personId, String avatar, {Uint8List? photo});
  Future<void> setAvatarLock(String personId, bool locked);

  // ---- tasks
  Future<void> addTask({required String title, required String personId, required int points, required Period repeat});
  Future<void> updateTask({required String taskId, required String title, required String personId, required int points, required Period repeat});
  Future<void> deleteTask(String taskId);
  Future<void> completeTask(String taskId, {Uint8List? photo});
  Future<void> decideCompletion(String completionId, bool approve);
  Future<ImageProvider?> proofImage(Completion c);

  // ---- competitions
  Future<void> addCompetition({required String title, required int startPoints, required int minutes});
  Future<void> endCompetition(String compId);
  Future<({int rank, int points})> enterCompetition(String compId);
  Future<void> decideEntry(String compId, String personId, bool approve);

  // ---- prizes
  Future<void> addPrize({required String name, required String emoji, required Span period, required DateTime awardAt});
  Future<void> deletePrize(String prizeId);

  /// Lets the server hand over prizes whose time came (the app calls it when one is due).
  Future<void> tick();

  // ---- prayer reminders
  Future<void> setPrayer({required double lat, required double lng, required int points, required bool enabled});

  // ---- notices
  /// [minutes] > 0 makes a timed alert that ends after that many minutes.
  Future<void> sendAlert(String to, String body, {int minutes = 0});
  Future<void> deleteAlert(String noticeId);
  Future<void> sendReport({Span span = Span.daily});
  Future<void> markRead();

  // ---- evaluation cycles and violations (owner)
  /// Wipes every member's points and starts a new year-long cycle.
  Future<void> newCycle();
  /// [personId] is a member id or 'all'.
  Future<void> addViolation({required String personId, required int points, String reason = ''});
  /// Cancels a violation and gives its points back.
  Future<void> deleteViolation(String violationId);

  // ---- honor board goals
  Future<void> addGoal({required String title, required int target, required String personId, required Honor period});
  Future<void> goalProgress(String goalId, int delta);
  Future<void> deleteGoal(String goalId);

  // ---- account
  Future<void> deleteAccount();
  Future<void> deleteFamily();

  // ---- activation codes (work before sign-in)
  /// Binds [code] to [deviceId] on first use; later it only works on that device.
  Future<void> redeemCode(String code, String deviceId);

  // ---- feedback (works signed in or not)
  Future<void> sendFeedback({required String type, required String text, String? email, required String platform});

  Future<void> dispose() async {}
}
