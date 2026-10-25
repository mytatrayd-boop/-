import 'dart:typed_data';

import '../models/analysis_result.dart';
import '../models/coffee_type.dart';
import '../models/usage.dart';

/// التحليل والعدّاد. الحد يفرضه الخادم؛ وضع العرض يحاكيه محلياً فقط.
abstract interface class AnalysisRepository {
  Future<AnalysisResult> analyze(
    Uint8List imageBytes, {
    required CoffeeType type,
    required String languageCode,
  });

  Future<Usage> usage();
}
