import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/scan.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../share_flow.dart';

/// زر «مشاركة» قابل لإعادة الاستخدام (تفاصيل الفحص الآن، وشاشة النتيجة لاحقاً).
class ShareScanButton extends ConsumerStatefulWidget {
  const ShareScanButton({super.key, required this.scan});

  final Scan scan;

  @override
  ConsumerState<ShareScanButton> createState() => _ShareScanButtonState();
}

class _ShareScanButtonState extends ConsumerState<ShareScanButton> {
  bool _busy = false;

  Future<void> _share() async {
    final origin = originFromContext(context); // قبل استبدال الزر بالمؤشر
    setState(() => _busy = true);
    try {
      await shareScan(context, ref, widget.scan, origin: origin);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_busy) {
      return Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l10n.shareGenerating),
        ),
      );
    }
    return IconButton(
      tooltip: l10n.shareAction,
      icon: const Icon(Icons.ios_share),
      onPressed: _share,
    );
  }
}
