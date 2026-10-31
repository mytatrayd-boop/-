import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/analysis.dart';
import '../../domain/scan.dart';
import 'scan_providers.dart';

sealed class ScanFlowState {
  const ScanFlowState();
}

class ScanIdle extends ScanFlowState {
  const ScanIdle();
}

class ScanPreview extends ScanFlowState {
  const ScanPreview(this.bytes);
  final Uint8List bytes;
}

class ScanAnalyzing extends ScanFlowState {
  const ScanAnalyzing(this.bytes);
  final Uint8List bytes;
}

/// فشل لا يُحتسب (الصورة باقية لإعادة المحاولة). [unclear]: الصورة غير صالحة.
class ScanFailed extends ScanFlowState {
  const ScanFailed(this.bytes, {this.error, this.unclear = false});
  final Uint8List bytes;
  final AnalysisError? error;
  final bool unclear;
}

class ScanDone extends ScanFlowState {
  const ScanDone(this.scanId);
  final int scanId;
}

class ScanTypeNotifier extends Notifier<ScanType> {
  @override
  ScanType build() => ScanType.bean;
  void set(ScanType t) => state = t;
}

final scanTypeProvider = NotifierProvider<ScanTypeNotifier, ScanType>(ScanTypeNotifier.new);

class ScanFlow extends Notifier<ScanFlowState> {
  int _run = 0;

  @override
  ScanFlowState build() => const ScanIdle();

  void preview(Uint8List bytes) => state = ScanPreview(bytes);

  void reset() {
    _run++;
    state = const ScanIdle();
  }

  /// يرسل الصورة. الإلغاء (reset) أثناء الانتظار يتجاهل النتيجة ولا يحفظ شيئاً.
  Future<void> analyze(Uint8List bytes) async {
    final run = ++_run;
    final type = ref.read(scanTypeProvider);
    state = ScanAnalyzing(bytes);
    try {
      final r = await ref.read(analysisServiceProvider).analyze(type, bytes);
      if (run != _run) return;
      if (!r.isOk) {
        state = ScanFailed(bytes, unclear: true);
        return;
      }
      final saved = await ref.read(scanRepositoryProvider).save(r.toNewScan(type, bytes));
      if (run != _run) return;
      state = ScanDone(saved.id);
    } on AnalysisException catch (e) {
      if (run == _run) state = ScanFailed(bytes, error: e.error);
    } catch (_) {
      if (run == _run) state = ScanFailed(bytes, error: AnalysisError.unknown);
    }
  }
}

final scanFlowProvider = NotifierProvider<ScanFlow, ScanFlowState>(ScanFlow.new);
