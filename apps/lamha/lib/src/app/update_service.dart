import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'app_version.dart';

/// تحديث أحدث من المثبّت متاح في المتجر (DECISIONS ٤٠).
class AppUpdate {
  const AppUpdate({this.storeUrl});

  /// آيفون: رابط التطبيق في App Store. أندرويد: null (يتولاه Play بنافذته).
  final String? storeUrl;
}

/// يسأل المتجر عن تحديث، ويبدأ تنزيله. خلف واجهة لتُستبدل في الاختبارات.
abstract interface class UpdateChecker {
  /// null إن لم يوجد تحديث أو تعذّر السؤال (بلا نت، أو لم يُثبَّت من المتجر): لا يزعج المستخدم أبداً.
  Future<AppUpdate?> check();

  /// ينقل المستخدم إلى تنزيل التحديث.
  Future<void> start(AppUpdate update);
}

class NoopUpdateChecker implements UpdateChecker {
  @override
  Future<AppUpdate?> check() async => null;
  @override
  Future<void> start(AppUpdate update) async {}
}

/// أندرويد: واجهة التحديث داخل التطبيق في Google Play (تعمل لما ثُبّت من Play، ومنه مسارات الاختبار).
/// آيفون: iTunes lookup بمعرّف الحزمة، فإن كان إصدار المتجر أحدث من [appVersionName] فرابطه.
class StoreUpdateChecker implements UpdateChecker {
  @visibleForTesting
  static const bundleId = 'sa.lamha.lamha';

  @override
  Future<AppUpdate?> check() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await InAppUpdate.checkForUpdate();
        return info.updateAvailability == UpdateAvailability.updateAvailable ? const AppUpdate() : null;
      }
      return await _checkAppStore();
    } catch (_) {
      return null;
    }
  }

  Future<AppUpdate?> _checkAppStore() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await c.getUrl(Uri.parse('https://itunes.apple.com/lookup?bundleId=$bundleId&country=sa'));
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final results = body['results'];
      if (results is! List || results.isEmpty) return null;
      final r = results.first as Map<String, dynamic>;
      final store = r['version'] as String?;
      final url = r['trackViewUrl'] as String?;
      if (store == null || url == null || !isNewer(store, appVersionName)) return null;
      return AppUpdate(storeUrl: url);
    } finally {
      c.close(force: true);
    }
  }

  /// هل [a] أحدث من [b] (أرقام مفصولة بنقاط: 1.10.0 > 1.9.2).
  @visibleForTesting
  static bool isNewer(String a, String b) {
    List<int> parts(String v) => v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
      if (p != q) return p > q;
    }
    return false;
  }

  @override
  Future<void> start(AppUpdate update) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return;
        }
        if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
          return;
        }
      } catch (_) {}
      // تعذّرت نافذة التحديث داخل التطبيق: صفحة التطبيق في Play.
      await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=sa.lamha.lamha'), mode: LaunchMode.externalApplication);
      return;
    }
    final url = update.storeUrl;
    if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  final mobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  return mobile ? StoreUpdateChecker() : NoopUpdateChecker();
});

/// عند وجود تحديث ينبّه المستخدم بنافذة «يتوفر تحديث جديد» وينقله إلى تنزيله. يسأل عند فتح التطبيق، وعند
/// عودته من الخلفية إن مضت [recheckAfter] على آخر سؤال. «لاحقاً» لا تعيد النافذة في الجلسة نفسها.
class UpdatePrompt extends ConsumerStatefulWidget {
  const UpdatePrompt({super.key, required this.child, this.recheckAfter = const Duration(hours: 12)});
  final Widget child;
  final Duration recheckAfter;

  @override
  ConsumerState<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends ConsumerState<UpdatePrompt> with WidgetsBindingObserver {
  DateTime? _lastCheck;
  var _showing = false;
  var _dismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (last == null || DateTime.now().difference(last) >= widget.recheckAfter) _check();
  }

  Future<void> _check() async {
    if (_showing || _dismissed || !mounted) return;
    _lastCheck = DateTime.now();
    final checker = ref.read(updateCheckerProvider);
    final update = await checker.check();
    if (update == null || !mounted || _showing) return;
    _showing = true;
    final t = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.updateTitle),
        content: Text(t.updateBody),
        actions: [
          TextButton(key: const Key('update-later'), onPressed: () => Navigator.pop(ctx, false), child: Text(t.updateLater)),
          FilledButton(key: const Key('update-now'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.updateNow)),
        ],
      ),
    );
    _showing = false;
    if (go == true) {
      await checker.start(update);
    } else {
      _dismissed = true;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
