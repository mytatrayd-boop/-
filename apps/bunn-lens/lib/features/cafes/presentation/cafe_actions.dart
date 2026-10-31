import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/cafe.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../cafes_providers.dart';
import '../data/location_service.dart';
import 'cafe_name_dialog.dart';

/// يفتح مكان المقهى في خرائط قوقل (رابط إحداثيات بلا مفتاح). لا يفعل شيئاً إن لم يوجد موقع.
Future<void> openCafeInMaps(BuildContext context, WidgetRef ref, Cafe cafe) async {
  final uri = cafe.mapsUri;
  if (uri == null) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  bool ok;
  try {
    ok = await ref.read(urlOpenerProvider)(uri);
  } catch (_) {
    ok = false;
  }
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(l10n.cafeOpenFailed)));
}

String _failureMessage(AppLocalizations l10n, LocationFailure f) => switch (f) {
      LocationFailure.denied => l10n.cafeLocDenied,
      LocationFailure.deniedForever => l10n.cafeLocDeniedForever,
      LocationFailure.serviceDisabled => l10n.cafeLocServiceOff,
      LocationFailure.timeout => l10n.cafeLocTimeout,
      LocationFailure.error => l10n.cafeLocError,
    };

/// «احفظ مكان المقهى»: إذن الموقع ← الموقع الحالي بمهلة ← الاسم (اقتراحات) ← الحفظ والربط بالفحص.
/// رفض الإذن أو فشل الموقع = رسالة، ثم متابعة بالاسم فقط أو إلغاء. يعيد true إن حُفظ.
Future<bool> saveCafeForScan(BuildContext context, WidgetRef ref, int scanId) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 16),
          Expanded(child: Text(l10n.cafeLocating)),
        ]),
      ),
    ),
  ));
  LocationResult location;
  try {
    location = await ref.read(locationServiceProvider).getCurrentLocation();
  } catch (_) {
    location = const LocationResult.failure(LocationFailure.error);
  }
  navigator.pop();
  if (!context.mounted) return false;

  if (!location.isSuccess) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cafeLocationFailedTitle),
        content: Text(_failureMessage(l10n, location.failure!)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.cafeSaveNameOnly)),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return false;
  }

  final cafes = ref.read(cafeRepositoryProvider);
  List<String> suggestions;
  try {
    suggestions = (await cafes.watchAll().first).map((s) => s.cafe.name).toList();
  } catch (_) {
    suggestions = const [];
  }
  if (!context.mounted) return false;
  final name = await showCafeNameDialog(context,
      title: l10n.cafeNameTitle, suggestions: suggestions);
  if (name == null) return false;

  try {
    final cafe = await cafes.save(name, lat: location.lat, lng: location.lng);
    final linked = await ref.read(scanRepositoryProvider).setCafe(scanId, cafe.id);
    if (!linked) throw StateError('scan $scanId not found');
    messenger.showSnackBar(SnackBar(content: Text(l10n.cafeSaved)));
    return true;
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.cafeSaveFailed)));
    return false;
  }
}

/// تعديل اسم المقهى.
Future<void> renameCafe(BuildContext context, WidgetRef ref, Cafe cafe) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final name = await showCafeNameDialog(context, title: l10n.cafeEditTitle, initial: cafe.name);
  if (name == null || name == cafe.name) return;
  try {
    await ref.read(cafeRepositoryProvider).rename(cafe.id, name);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.cafeRenameFailed)));
  }
}

/// حذف بتأكيد. يعيد true إن حُذف.
Future<bool> confirmAndDeleteCafe(BuildContext context, WidgetRef ref, Cafe cafe) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.cafeDeleteTitle),
      content: Text(l10n.cafeDeleteBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.scanDelete, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    final ok = await ref.read(cafeRepositoryProvider).delete(cafe.id);
    if (ok) messenger.showSnackBar(SnackBar(content: Text(l10n.cafeDeleted)));
    return ok;
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.cafeDeleteFailed)));
    return false;
  }
}
