import 'app_failure.dart';
import 'usage.dart';

/// نتيجة التحليل حسب عقد SPEC §3.1. أي مخالفة للعقد ترمي FormatException.
class AnalysisResult {
  const AnalysisResult({
    required this.imageValid,
    this.reason,
    this.score,
    this.notes = const [],
    this.tip,
    this.usage,
  });

  final bool imageValid;
  final InvalidImageReason? reason;
  final double? score;
  final List<String> notes;
  final String? tip;
  final Usage? usage;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final valid = json['image_valid'];
    if (valid is! bool) throw const FormatException('image_valid');
    final usageJson = json['usage'];
    final usage =
        usageJson is Map<String, dynamic> ? Usage.fromJson(usageJson) : null;
    if (!valid) {
      final reason = InvalidImageReason.fromWire(json['reason'] as String?);
      if (reason == null) throw const FormatException('reason');
      return AnalysisResult(imageValid: false, reason: reason, usage: usage);
    }
    final score = json['score'];
    if (score is! num || score < 0 || score > 10 || (score * 2) % 1 != 0) {
      throw const FormatException('score');
    }
    final notes = json['notes'];
    if (notes is! List ||
        notes.length != 3 ||
        notes.any((n) => n is! String || n.isEmpty || n.length > 120)) {
      throw const FormatException('notes');
    }
    final tip = json['tip'];
    if (tip is! String || tip.isEmpty || tip.length > 160) {
      throw const FormatException('tip');
    }
    return AnalysisResult(
      imageValid: true,
      score: score.toDouble(),
      notes: List<String>.unmodifiable(notes.cast<String>()),
      tip: tip,
      usage: usage,
    );
  }

  Map<String, dynamic> toJson() => {
        'image_valid': imageValid,
        'reason': reason?.wire,
        'score': score,
        'notes': notes,
        'tip': tip,
        if (usage != null) 'usage': usage!.toJson(),
      };
}
