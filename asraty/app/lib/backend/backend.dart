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
  Future<bool> requestCode({required String email, required Role role, String? familyName, String? name, bool resend = false});
  Future<VerifyResult> verifyCode({required String email, required String code});
  Future<void> signOut();

  // ---- people
  Future<void> addPerson({required Role role, required String name, required String email, required String avatar, Map<Perm, bool>? perms});
  Future<void> resendInvite(String personId);
  Future<void> updatePerms(String personId, Map<Perm, bool> perms);
  Future<void> removePerson(String personId);
  Future<void> setAvatar(String personId, String avatar);

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

  // ---- rewards
  Future<void> addTier({required String name, required String emoji, required int threshold, required Period period, required Scope scope});
  Future<void> deleteTier(String tierId);
  Future<void> deliver(String tierId, String who, String periodKey);

  // ---- notices
  Future<void> sendAlert(String to, String body);
  Future<void> sendReport();
  Future<void> markRead();

  // ---- account
  Future<void> deleteAccount();
  Future<void> deleteFamily();

  // ---- feedback (works signed in or not)
  Future<void> sendFeedback({required String type, required String text, String? email, required String platform});

  Future<void> dispose() async {}
}
