// المشاريع المحفوظة: كل مشروع مجلد فيه project.json ونسخ من الملفات الصوتية والخلفيات،
// فيبقى المشروع صالحاً حتى لو حُذفت الملفات الأصلية من الجوال.
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// مقطع صوتي في المشروع: ملفه داخل مجلد المشروع، ومكانه في الخط الزمني المدمج (بالثواني).
class ClipInfo {
  final String file, name;
  double start, end;
  ClipInfo(this.file, this.name, this.start, this.end);
  Map<String, dynamic> toJson() => {'file': file, 'name': name, 'start': start, 'end': end};
  factory ClipInfo.fromJson(Map<String, dynamic> j) =>
      ClipInfo(j['file'] as String, j['name'] as String? ?? '', (j['start'] as num).toDouble(), (j['end'] as num).toDouble());
}

/// بطاقة المشروع في القائمة (بلا تحميل المشروع كاملاً).
class ProjectMeta {
  final String id, name, summary;
  final DateTime updated;
  final double duration;
  final int clips;
  ProjectMeta(this.id, this.name, this.summary, this.updated, this.duration, this.clips);
}

class ProjectStore {
  static Future<Directory> root() async =>
      Directory('${(await getApplicationDocumentsDirectory()).path}/tilawa_projects')..createSync(recursive: true);

  static Future<Directory> dir(String id) async => Directory('${(await root()).path}/$id')..createSync(recursive: true);

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  static Future<List<ProjectMeta>> list() async {
    final out = <ProjectMeta>[];
    for (final d in (await root()).listSync().whereType<Directory>()) {
      final f = File('${d.path}/project.json');
      if (!f.existsSync()) continue;
      try {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        out.add(ProjectMeta(
          j['id'] as String,
          j['name'] as String? ?? 'مشروع',
          j['summary'] as String? ?? '',
          DateTime.fromMillisecondsSinceEpoch((j['updated'] as num?)?.toInt() ?? 0),
          (j['duration'] as num?)?.toDouble() ?? 0,
          (j['clips'] as List?)?.length ?? 0,
        ));
      } catch (_) {
        // ملف تالف: يُتجاوز ولا يُحذف
      }
    }
    out.sort((a, b) => b.updated.compareTo(a.updated));
    return out;
  }

  /// كتابة آمنة: ملف مؤقت ثم إعادة تسمية، فلا يتلف المشروع إن انقطع الحفظ.
  static Future<void> save(String id, Map<String, dynamic> data) async {
    final d = await dir(id);
    final tmp = File('${d.path}/project.json.tmp');
    await tmp.writeAsString(jsonEncode(data));
    await tmp.rename('${d.path}/project.json');
  }

  static Future<Map<String, dynamic>?> load(String id) async {
    final f = File('${(await dir(id)).path}/project.json');
    if (!f.existsSync()) return null;
    return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
  }

  static Future<void> delete(String id) async {
    final d = Directory('${(await root()).path}/$id');
    if (d.existsSync()) d.deleteSync(recursive: true);
  }
}
