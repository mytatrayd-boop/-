import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config.dart';
import '../core/logic.dart';
import '../core/models.dart';
import 'backend.dart';
import 'push.dart';

DateTime _ts(Object? v) => v is Timestamp ? v.toDate() : DateTime.now();
int _int(Object? v) => v is num ? v.toInt() : 0;

/// Real backend: reads via Firestore listeners (read-only rules), every write
/// goes through the `api` callable function, which checks permissions and
/// owns all point changes.
class FirebaseBackend extends Backend {
  FirebaseBackend() {
    _authSub = _auth.idTokenChanges().listen(_onUser);
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      // Re-subscribe period-scoped queries when the Riyadh day rolls over.
      final k = dayKey(DateTime.now());
      if (_session != null && k != _dayKey) _listen(_session!);
    });
  }

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _fn = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  StreamSubscription<User?>? _authSub;
  Timer? _dayTimer;
  final _subs = <StreamSubscription>[];
  Session? _session;
  String _dayKey = '';
  String? _fcmToken;

  // Latest raw pieces, combined into one snapshot.
  String? _famName;
  List<Person>? _people;
  List<TaskItem> _tasks = [];
  List<Completion> _completions = [];
  List<Competition> _comps = [];
  List<Tier> _tiers = [];
  Set<String> _deliveries = {};
  List<Notice> _notices = [];
  Map<String, PeriodSum> _daily = {}, _weekly = {};

  @override
  bool get isDemo => false;

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic> data = const {}]) async {
    try {
      // The API runs on SERVER_URL (Netlify) when set, else as Cloud Functions.
      final callable = AppConfig.serverUrl.isNotEmpty
          ? _fn.httpsCallableFromUri(Uri.parse('${AppConfig.serverUrl}/api/$name'))
          : _fn.httpsCallable(name);
      final r = await callable.call<dynamic>(data);
      final d = r.data;
      return d is Map ? Map<String, dynamic>.from(d) : {};
    } on FirebaseFunctionsException catch (e) {
      final det = e.details;
      final code = det is Map && det['code'] is String ? det['code'] as String : (e.code == 'unavailable' ? 'network' : e.message ?? e.code);
      throw AppError(code, det is Map ? Map<String, dynamic>.from(det) : const {});
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError('network');
    }
  }

  Future<Map<String, dynamic>> _op(String op, [Map<String, dynamic> data = const {}]) => _call('api', {'op': op, ...data});

  // ---------------------------------------------------------------- session
  Future<void> _onUser(User? user) async {
    if (user == null) {
      _stop();
      _session = null;
      emit(const AppState());
      return;
    }
    final claims = (await user.getIdTokenResult()).claims ?? {};
    final fid = claims['familyId'];
    if (fid is! String) {
      await _auth.signOut();
      return;
    }
    final s = Session(personId: user.uid, familyId: fid, role: roleFrom(claims['role']));
    if (_session?.personId == s.personId && _session?.familyId == s.familyId) return;
    _session = s;
    emit(AppState(session: s, loading: true));
    _listen(s);
    unawaited(_setupPush());
  }

  void _stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _famName = null;
    _people = null;
  }

  void _listen(Session s) {
    _stop();
    final now = DateTime.now();
    _dayKey = dayKey(now);
    final wk = weekKey(now);
    final f = _db.collection('families').doc(s.familyId);
    void on<T>(Stream<T> st, void Function(T) fn) => _subs.add(st.listen((v) {
          fn(v);
          _publish();
        }, onError: (Object e) => debugPrint('listen error: $e')));

    on(f.snapshots(), (DocumentSnapshot<Map<String, dynamic>> d) {
      _famName = d.data()?['name'] as String?;
      if (!d.exists) _auth.signOut();
    });
    on(f.collection('people').snapshots(), (QuerySnapshot<Map<String, dynamic>> q) {
      _people = q.docs.map((d) {
        final x = d.data();
        return Person(
          id: d.id, name: x['name'] ?? '', email: x['email'] ?? '', role: roleFrom(x['role']),
          avatar: x['avatar'] ?? 'boy', active: x['status'] == 'active', perms: permsFrom(x['perms']));
      }).toList()
        ..sort((a, b) => a.role.index.compareTo(b.role.index));
      // Removed from the family → sign out.
      if (!_people!.any((p) => p.id == s.personId)) _auth.signOut();
    });
    on(f.collection('tasks').snapshots(), (QuerySnapshot<Map<String, dynamic>> q) {
      _tasks = q.docs.map((d) {
        final x = d.data();
        return TaskItem(id: d.id, title: x['title'] ?? '', personId: x['personId'] ?? '', points: _int(x['points']), repeat: periodFrom(x['repeat']));
      }).toList();
    });
    on(f.collection('completions').where('periodKey', whereIn: [_dayKey, wk]).snapshots(), (QuerySnapshot<Map<String, dynamic>> q) {
      _completions = q.docs.map((d) {
        final x = d.data();
        return Completion(
          id: d.id, taskId: x['taskId'] ?? '', personId: x['personId'] ?? '', title: x['title'] ?? '',
          points: _int(x['points']), periodKey: x['periodKey'] ?? '', status: statusFrom(x['status']),
          createdAt: _ts(x['createdAt']), photoPath: x['hasPhoto'] == true ? d.id : null);
      }).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    on(f.collection('competitions').orderBy('createdAt', descending: true).limit(20).snapshots(), (QuerySnapshot<Map<String, dynamic>> q) {
      _comps = q.docs.map((d) {
        final x = d.data();
        final entries = <String, Entry>{};
        (x['entries'] as Map? ?? {}).forEach((k, v) {
          if (v is Map) entries[k as String] = Entry(personId: k, rank: _int(v['rank']), points: _int(v['points']), status: statusFrom(v['status']));
        });
        return Competition(
          id: d.id, title: x['title'] ?? '', startPoints: _int(x['startPoints']), createdAt: _ts(x['createdAt']),
          deadline: x['deadline'] is Timestamp ? (x['deadline'] as Timestamp).toDate() : null, ended: x['ended'] == true, entries: entries);
      }).toList();
    });
    on(f.collection('tiers').snapshots(), (QuerySnapshot<Map<String, dynamic>> q) {
      _tiers = q.docs.map((d) {
        final x = d.data();
        return Tier(id: d.id, name: x['name'] ?? '', emoji: x['emoji'] ?? '🎁', threshold: _int(x['threshold']), period: periodFrom(x['period']), scope: scopeFrom(x['scope']));
      }).toList();
    });
    on(f.collection('deliveries').where('periodKey', whereIn: [_dayKey, wk]).snapshots(), (QuerySnapshot<Map<String, dynamic>> q) {
      _deliveries = q.docs.map((d) => d.id).toSet();
    });
    // Members filter by recipient (no ordering, so no composite index is needed;
    // the server keeps only the last 60 days). Sorted newest first below.
    final Query<Map<String, dynamic>> nq = s.role == Role.member
        ? f.collection('notifications').where('to', whereIn: ['all', s.personId])
        : f.collection('notifications').orderBy('createdAt', descending: true).limit(50);
    on(nq.snapshots(), (QuerySnapshot<Map<String, dynamic>> q) {
      _notices = q.docs.map((d) {
        final x = d.data();
        return Notice(
          id: d.id, to: x['to'] ?? 'all', title: x['title'] ?? '', body: x['body'] ?? '', from: x['from'] ?? '',
          createdAt: _ts(x['createdAt']), readBy: List<String>.from(x['readBy'] ?? const []));
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
    on(f.collection('summaries').where('periodKey', whereIn: [_dayKey, wk]).snapshots(), (QuerySnapshot<Map<String, dynamic>> q) {
      _daily = {};
      _weekly = {};
      for (final d in q.docs) {
        final x = d.data();
        final sum = PeriodSum(_int(x['points']), _int(x['count']));
        (x['periodKey'] == _dayKey ? _daily : _weekly)[x['personId'] as String] = sum;
      }
    });
  }

  void _publish() {
    final s = _session;
    if (s == null) return;
    if (_famName == null || _people == null) {
      emit(AppState(session: s, loading: true));
      return;
    }
    emit(AppState(
      session: s,
      data: FamilySnapshot(
        familyName: _famName!, people: _people!, tasks: _tasks, completions: _completions, competitions: _comps,
        tiers: _tiers, deliveries: _deliveries, notices: _notices, daily: _daily, weekly: _weekly),
    ));
  }

  Future<void> _setupPush() async {
    if (kIsWeb) return;
    try {
      final m = FirebaseMessaging.instance;
      final perm = await m.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      await Push.init();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // APNs token must exist before an FCM token can be fetched on iOS.
        for (var i = 0; i < 10 && await m.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      _fcmToken = await m.getToken();
      if (_fcmToken != null) await _op('registerToken', {'token': _fcmToken});
      m.onTokenRefresh.listen((t) {
        _fcmToken = t;
        if (_session != null) _op('registerToken', {'token': t}).ignore();
      });
    } catch (e) {
      debugPrint('push setup failed: $e');
    }
  }

  // ---------------------------------------------------------------- auth
  @override
  Future<bool> requestCode({required String email, required Role role, String? familyName, String? name, bool resend = false}) async {
    final r = await _call('requestCode', {
      'email': email, 'role': role == Role.member ? 'member' : 'admin',
      'familyName': ?familyName, 'name': ?name, 'resend': resend,
    });
    return r['sent'] == true;
  }

  @override
  Future<VerifyResult> verifyCode({required String email, required String code}) async {
    final r = await _call('verifyCode', {'email': email, 'code': code});
    await _auth.signInWithCustomToken(r['token'] as String);
    return VerifyResult(first: r['first'] == true, familyName: r['familyName'] ?? '', name: '');
  }

  @override
  Future<void> signOut() async {
    if (_fcmToken != null) {
      try {
        await _op('unregisterToken', {'token': _fcmToken});
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // ---------------------------------------------------------------- people
  @override
  Future<void> addPerson({required Role role, required String name, required String email, required String avatar, Map<Perm, bool>? perms}) =>
      _op('addPerson', {'role': role.name, 'name': name, 'email': email, 'avatar': avatar, 'perms': permsToJson(perms ?? {})});

  @override
  Future<void> resendInvite(String personId) => _op('resendInvite', {'personId': personId});

  @override
  Future<void> updatePerms(String personId, Map<Perm, bool> perms) => _op('updatePerms', {'personId': personId, 'perms': permsToJson(perms)});

  @override
  Future<void> removePerson(String personId) => _op('removePerson', {'personId': personId});

  @override
  Future<void> setAvatar(String personId, String avatar) => _op('setAvatar', {'personId': personId, 'avatar': avatar});

  // ---------------------------------------------------------------- tasks
  @override
  Future<void> addTask({required String title, required String personId, required int points, required Period repeat}) =>
      _op('addTask', {'title': title, 'personId': personId, 'points': points, 'repeat': repeat.name});

  @override
  Future<void> updateTask({required String taskId, required String title, required String personId, required int points, required Period repeat}) =>
      _op('updateTask', {'taskId': taskId, 'title': title, 'personId': personId, 'points': points, 'repeat': repeat.name});

  @override
  Future<void> deleteTask(String taskId) => _op('deleteTask', {'taskId': taskId});

  @override
  Future<void> completeTask(String taskId, {Uint8List? photo}) =>
      // The photo (already resized to 720px on the device) travels with the request
      // and is stored by the server until the task is approved or rejected.
      _op('completeTask', {'taskId': taskId, if (photo != null) 'photo': base64Encode(photo)});

  @override
  Future<void> decideCompletion(String completionId, bool approve) => _op('decideCompletion', {'completionId': completionId, 'approve': approve});

  final _proofCache = <String, Future<ImageProvider?>>{};

  @override
  Future<ImageProvider?> proofImage(Completion c) {
    final s = _session;
    if (c.photoPath == null || s == null) return Future.value();
    return _proofCache.putIfAbsent(c.id, () async {
      try {
        final d = await _db.collection('families').doc(s.familyId).collection('proofs').doc(c.id).get();
        final b64 = d.data()?['data'];
        return b64 is String ? MemoryImage(base64Decode(b64)) : null;
      } catch (_) {
        _proofCache.remove(c.id);
        return null;
      }
    });
  }

  // ---------------------------------------------------------------- competitions
  @override
  Future<void> addCompetition({required String title, required int startPoints, required int minutes}) =>
      _op('addCompetition', {'title': title, 'startPoints': startPoints, 'minutes': minutes});

  @override
  Future<void> endCompetition(String compId) => _op('endCompetition', {'compId': compId});

  @override
  Future<({int rank, int points})> enterCompetition(String compId) async {
    final r = await _op('enterCompetition', {'compId': compId});
    return (rank: _int(r['rank']), points: _int(r['points']));
  }

  @override
  Future<void> decideEntry(String compId, String personId, bool approve) =>
      _op('decideEntry', {'compId': compId, 'personId': personId, 'approve': approve});

  // ---------------------------------------------------------------- rewards
  @override
  Future<void> addTier({required String name, required String emoji, required int threshold, required Period period, required Scope scope}) =>
      _op('addTier', {'name': name, 'emoji': emoji, 'threshold': threshold, 'period': period.name, 'scope': scope.name});

  @override
  Future<void> deleteTier(String tierId) => _op('deleteTier', {'tierId': tierId});

  @override
  Future<void> deliver(String tierId, String who, String periodKey) => _op('deliver', {'tierId': tierId, 'who': who, 'periodKey': periodKey});

  // ---------------------------------------------------------------- notices
  @override
  Future<void> sendAlert(String to, String body) => _op('sendAlert', {'to': to, 'body': body});

  @override
  Future<void> sendReport() => _op('sendReport');

  @override
  Future<void> markRead() => _op('markRead');

  // ---------------------------------------------------------------- account
  @override
  Future<void> deleteAccount() async {
    await _op('deleteAccount');
    await _auth.signOut();
  }

  @override
  Future<void> deleteFamily() async {
    await _op('deleteFamily');
    await _auth.signOut();
  }

  @override
  Future<void> sendFeedback({required String type, required String text, String? email, required String platform}) =>
      _call('sendFeedback', {'type': type, 'text': text, 'email': ?email, 'platform': platform});

  @override
  Future<void> dispose() async {
    _stop();
    _dayTimer?.cancel();
    await _authSub?.cancel();
  }
}
