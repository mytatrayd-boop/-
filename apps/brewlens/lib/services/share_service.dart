import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// مشاركة صورة PNG مولّدة فقط؛ لا روابط تخزين (SPEC F8 معيار 3).
abstract interface class ShareService {
  /// إلغاء المستخدم ليس خطأ. يرمي عند فشل الكتابة أو المشاركة.
  Future<void> shareImage(Uint8List png, {Rect? origin});
}

class SharePlusService implements ShareService {
  const SharePlusService();

  static const fileName = 'brewlens_card.png';

  @override
  Future<void> shareImage(Uint8List png, {Rect? origin}) async {
    // ملف واحد يُستبدل في كل مرة داخل المجلد المؤقت.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(png, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      sharePositionOrigin: origin,
    ));
  }
}
