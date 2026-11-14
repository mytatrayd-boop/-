import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/permissions/permission_service.dart';
import '../../l10n/app_localizations.dart';
import 'permissions_controller.dart';

/// شاشة الأذونات (F4، DESIGN 7.1): شرح قبل الطلب، 3 خطوات.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(permissionsProvider.notifier).refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// عند العودة من إعدادات الجوال تُعاد الفحوص تلقائياً.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      ref.read(permissionsProvider.notifier).refreshAndAdvance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final st = ref.watch(permissionsProvider);
    final c = ref.read(permissionsProvider.notifier);

    ref.listen(permissionsProvider.select((s) => s.done), (_, done) {
      if (done && context.mounted) context.go(AppRoutes.home);
    });

    final p = st.currentPermission;
    final status = st.statusOf(p);
    final asked = st.asked.contains(p);
    final isMic = p == AppPermission.microphone;
    final denied = asked && status != AppPermissionStatus.granted;
    final permanent =
        status == AppPermissionStatus.permanentlyDenied ||
        status == AppPermissionStatus.approximateOnly;

    final (title, reason, deniedMsg) = switch (p) {
      AppPermission.camera => (
        l.permCameraTitle,
        l.permCameraReason,
        l.permCameraDenied,
      ),
      AppPermission.location => (
        l.permLocationTitle,
        l.permLocationReason,
        status == AppPermissionStatus.approximateOnly
            ? l.permLocationApproximate
            : l.permLocationDenied,
      ),
      AppPermission.microphone => (
        l.permMicTitle,
        l.permMicReason,
        l.permMicDenied,
      ),
    };
    final icon = switch (p) {
      AppPermission.camera => Icons.videocam_outlined,
      AppPermission.location => Icons.place_outlined,
      AppPermission.microphone => Icons.mic_none,
    };
    final text = Theme.of(context).textTheme;

    final content = <Widget>[
      Text(
        l.permStepOf(st.step + 1, permissionSteps.length),
        textAlign: TextAlign.center,
        style: text.bodySmall,
      ),
      const SizedBox(height: 8),
      Semantics(
        label: l.permIllustration(title),
        child: ExcludeSemantics(
          child: Icon(icon, size: 48, color: AppColors.amber),
        ),
      ),
      const SizedBox(height: 8),
      Text(title, textAlign: TextAlign.center, style: text.titleLarge),
      const SizedBox(height: 4),
      Text(reason, textAlign: TextAlign.center, style: text.bodyLarge),
      if (denied) ...[
        const SizedBox(height: 12),
        if (isMic)
          Align(
            child: Chip(
              avatar: const Icon(Icons.mic_off, size: 18),
              label: Text(l.permAudioUnavailable),
            ),
          ),
        Text(
          deniedMsg,
          key: const Key('perm-denied-msg'),
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.warning),
        ),
        if (permanent && status != AppPermissionStatus.approximateOnly)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4),
            child: Text(
              l.permPermanentHint,
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ),
        if (!isMic)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4),
            child: Text(
              l.permStartBlocked,
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ),
      ],
    ];
    final actions = <Widget>[
      const SizedBox(height: 16),
      if (!denied)
        FilledButton(
          key: const Key('perm-allow'),
          onPressed: c.allow,
          child: Text(l.permAllow),
        )
      else ...[
        if (permanent)
          FilledButton(
            key: const Key('perm-settings'),
            onPressed: c.openSettings,
            child: Text(l.permOpenPhoneSettings),
          )
        else ...[
          FilledButton(
            key: const Key('perm-retry'),
            onPressed: c.retry,
            child: Text(l.permRetry),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('perm-settings'),
            onPressed: c.openSettings,
            child: Text(l.permOpenPhoneSettings),
          ),
        ],
      ],
      if (isMic) ...[
        const SizedBox(height: 8),
        TextButton(
          key: const Key('perm-skip'),
          onPressed: c.skipMicrophone,
          child: Text(denied ? l.permContinueNoAudio : l.permNotNow),
        ),
      ],
    ];
    final privacy = Text(
      l.permPrivacy,
      textAlign: TextAlign.center,
      style: text.bodySmall,
    );
    // أفقي (الوضع الأساسي للتطبيق): الشرح بجانب الأزرار كي لا تختفي تحت الطي.
    final wide =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Scaffold(
      appBar: AppBar(title: Text(l.permTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...content,
                                const SizedBox(height: 8),
                                privacy,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: actions,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...content,
                                const SizedBox(height: 8),
                                privacy,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...actions,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
