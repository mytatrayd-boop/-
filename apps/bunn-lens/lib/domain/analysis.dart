import 'scan.dart';
import 'score_tier.dart';

enum AnalysisStatus { ok, unclear, notCoffee }

/// نتيجة تحليل صورة من الوسيط. [score] للتخزين فقط؛ الواجهة تعرض [tier].
class AnalysisResult {
  AnalysisResult({
    required this.status,
    required this.score,
    required List<String> notes,
    this.promptVersion,
    this.remaining,
  }) : notes = List.unmodifiable(notes);

  final AnalysisStatus status;
  final int score;
  final List<String> notes;
  final String? promptVersion;
  final int? remaining;

  bool get isOk => status == AnalysisStatus.ok;
  ScoreTier get tier => tierOf(score);

  NewScan toNewScan(ScanType type, List<int> imageBytes) =>
      NewScan(type: type, score: score, notes: notes, imageBytes: imageBytes, promptVersion: promptVersion);
}

/// أسباب فشل لا تُحتسب كفحص.
enum AnalysisError { offline, busy, quotaExhausted, unauthorized, unknown }

class AnalysisException implements Exception {
  const AnalysisException(this.error);
  final AnalysisError error;
  @override
  String toString() => 'AnalysisException($error)';
}
