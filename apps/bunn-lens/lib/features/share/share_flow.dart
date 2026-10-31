import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/scan.dart';
import '../../l10n/gen/app_localizations.dart';
import 'presentation/user_name_dialog.dart';
import 'share_card_data.dart';
import 'share_card_renderer.dart';
import 'share_text.dart';
import 'user_name.dart';

/// يفتح قائمة المشاركة بالصورة والنص. يُستبدل في الاختبارات.
typedef ShareLauncher = Future<void> Function(Uint8List png, String text);

Future<void> _defaultLauncher(Uint8List png, String text) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, 'bunn_lens_share_${DateTime.now().millisecondsSinceEpoch}.png'));
  await file.writeAsBytes(png, flush: true);
  try {
    await SharePlus.instance.share(ShareParams(text: text, files: [XFile(file.path, mimeType: 'image/png')]));
  } finally {
    // مؤقتات الصورة تُحذف بعد المشاركة.
    if (await file.exists()) await file.delete();
  }
}

final shareLauncherProvider = Provider<ShareLauncher>((ref) => _defaultLauncher);

/// تدفق المشاركة: الاسم (يُطلب إن كان فارغاً) ← صورة الفحص ← رسم البطاقة PNG ← قائمة المشاركة.
/// يعيد true إن فُتحت قائمة المشاركة. لا يشارك أبداً بلا اسم أو بلا صورة فحص.
Future<bool> shareScan(BuildContext context, WidgetRef ref, Scan scan) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final direction = Directionality.of(context);
  final bundle = DefaultAssetBundle.of(context);
  final notifier = ref.read(userNameProvider.notifier);
  final launcher = ref.read(shareLauncherProvider);

  final current = await ref.read(userNameProvider.future);
  if (!context.mounted) return false;
  final name = await ensureUserName(
    current: current,
    ask: () => showUserNameDialog(context, title: l10n.shareNameDialogTitle, body: l10n.shareNameDialogBody),
    save: notifier.setName,
  );
  if (name == null || !context.mounted) return false;

  final photo = await loadScanPhoto(scan.imagePath);
  if (photo == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shareImageMissing)));
    return false;
  }
  if (!context.mounted) {
    photo.dispose();
    return false;
  }
  messenger.showSnackBar(SnackBar(content: Text(l10n.shareGenerating), duration: const Duration(seconds: 2)));
  ui.Image? logo;
  try {
    logo = await loadLogoMark(bundle);
    if (!context.mounted) return false;
    final data = ShareCardData.fromScan(
      l10n: l10n,
      scan: scan,
      userName: name,
      photo: photo,
      logo: logo,
      textDirection: direction,
    );
    final png = await renderShareCardPng(context, data);
    messenger.hideCurrentSnackBar();
    await launcher(png, buildShareText(l10n, scan));
    return true;
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    return false;
  } finally {
    photo.dispose();
    logo?.dispose();
  }
}
