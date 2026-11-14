import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// فشل المشاركة أو الفتح (خطأ نظام). إلغاء قائمة النظام ليس فشلاً.
class ShareException implements Exception {
  const ShareException(this.message);
  final String message;
  @override
  String toString() => 'ShareException($message)';
}

/// المشاركة وفتح الملفات والروابط. خلف واجهة (features لا تستدعي الأصلي).
abstract class ShareService {
  /// نص عبر قائمة مشاركة النظام.
  Future<void> shareText(String text);

  /// ملف موجود (الفيديو) عبر قائمة المشاركة.
  Future<void> shareFile(String path, {String? mimeType});

  /// يكتب [content] في ملف مؤقت باسم [fileName] ويشاركه. لا يحذفه فور العودة (التطبيق المستلم قد يقرؤه لاحقاً)؛
  /// الملفات المؤقتة الأقدم من يوم تُحذف قبل الكتابة التالية.
  Future<void> shareGeneratedFile(
    String content,
    String fileName, {
    String? mimeType,
  });

  /// يفتح الرابط في تطبيق خارجي (خرائط جوجل إن وُجد وإلا المتصفح).
  /// يعيد false إن تعذّر الفتح.
  Future<bool> openUrl(String url);

  /// يفتح ملفاً في مشغل النظام. يعيد false إن تعذّر.
  Future<bool> openFile(String path);

  /// هل الملف موجود على الجوال.
  Future<bool> fileExists(String path);
}

/// مجلد الملفات المؤقتة المولّدة للمشاركة (داخل المجلد المؤقت).
const shareTempDirName = 'rihla_share';

/// يحذف الملفات في [dir] الأقدم من [maxAge] (افتراضياً يوم). يتجاهل أي خطأ. يعيد عدد المحذوف.
Future<int> purgeStaleShareFiles(
  Directory dir, {
  Duration maxAge = const Duration(days: 1),
  DateTime? now,
}) async {
  var n = 0;
  try {
    final limit = (now ?? DateTime.now()).subtract(maxAge);
    await for (final e in dir.list()) {
      if (e is! File) continue;
      try {
        if ((await e.lastModified()).isBefore(limit)) {
          await e.delete();
          n++;
        }
      } catch (_) {}
    }
  } catch (_) {}
  return n;
}

class SystemShareService implements ShareService {
  const SystemShareService();

  @override
  Future<void> shareText(String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      throw ShareException(e.toString());
    }
  }

  @override
  Future<void> shareFile(String path, {String? mimeType}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path, mimeType: mimeType)]),
      );
    } catch (e) {
      throw ShareException(e.toString());
    }
  }

  @override
  Future<void> shareGeneratedFile(
    String content,
    String fileName, {
    String? mimeType,
  }) async {
    try {
      final base = await getTemporaryDirectory();
      final dir = Directory(p.join(base.path, shareTempDirName));
      await dir.create(recursive: true);
      await purgeStaleShareFiles(dir);
      final f = File(p.join(dir.path, fileName));
      await f.writeAsString(content, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path, mimeType: mimeType)]),
      );
    } catch (e) {
      throw ShareException(e.toString());
    }
  }

  @override
  Future<bool> openUrl(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openFile(String path) async {
    try {
      final r = await OpenFilex.open(path);
      return r.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> fileExists(String path) async {
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }
}

/// نسخة مزيّفة للاختبارات: تسجّل الاستدعاءات.
class FakeShareService implements ShareService {
  FakeShareService({Set<String>? existing}) : existing = existing ?? {};

  final Set<String> existing;
  final texts = <String>[];
  final files = <String>[];
  final generated = <({String content, String name, String? mime})>[];
  final openedUrls = <String>[];
  final openedFiles = <String>[];
  bool failShare = false;
  bool openUrlResult = true;
  bool openFileResult = true;

  void _maybeFail() {
    if (failShare) throw const ShareException('fake');
  }

  @override
  Future<void> shareText(String text) async {
    _maybeFail();
    texts.add(text);
  }

  @override
  Future<void> shareFile(String path, {String? mimeType}) async {
    _maybeFail();
    files.add(path);
  }

  @override
  Future<void> shareGeneratedFile(
    String content,
    String fileName, {
    String? mimeType,
  }) async {
    _maybeFail();
    generated.add((content: content, name: fileName, mime: mimeType));
  }

  @override
  Future<bool> openUrl(String url) async {
    openedUrls.add(url);
    return openUrlResult;
  }

  @override
  Future<bool> openFile(String path) async {
    openedFiles.add(path);
    return openFileResult;
  }

  @override
  Future<bool> fileExists(String path) async => existing.contains(path);
}

final shareServiceProvider = Provider<ShareService>(
  (_) => const SystemShareService(),
);
