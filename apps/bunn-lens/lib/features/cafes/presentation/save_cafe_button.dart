import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import 'cafe_actions.dart';

/// أيقونة «احفظ مكان المقهى» قابلة لإعادة الاستخدام (تفاصيل الفحص الآن، وشاشة النتيجة لاحقاً).
class SaveCafeButton extends ConsumerWidget {
  const SaveCafeButton({super.key, required this.scanId, this.hasCafe = false});

  final int scanId;

  /// الفحص مرتبط بمقهى مسبقاً (تتغير الأيقونة؛ الضغط يختار مقهى آخر).
  final bool hasCafe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.cafeSave,
      icon: Icon(hasCafe ? Icons.place : Icons.add_location_alt_outlined),
      onPressed: () => saveCafeForScan(context, ref, scanId),
    );
  }
}
