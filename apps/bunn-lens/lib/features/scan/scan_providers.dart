import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/analysis_service.dart';

const workerUrl = String.fromEnvironment('WORKER_URL');

final authTokensProvider = Provider<AuthTokens>((ref) => const NoAuthTokens());

final analysisServiceProvider = Provider<AnalysisService>(
  (ref) => HttpAnalysisService(baseUrl: workerUrl, tokens: ref.watch(authTokensProvider)),
);

enum PickSource { camera, gallery }

/// التقاط/اختيار صورة JPEG مضغوطة (≤1024px). يرجع null عند الإلغاء ويرمي عند الفشل (إذن مرفوض).
abstract class ImagePort {
  Future<Uint8List?> pick(PickSource source);
}

class ImagePickerPort implements ImagePort {
  @override
  Future<Uint8List?> pick(PickSource source) async {
    final f = await ImagePicker().pickImage(
      source: source == PickSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    return f?.readAsBytes();
  }
}

final imagePortProvider = Provider<ImagePort>((ref) => ImagePickerPort());

/// الموافقة على إفصاح إرسال الصورة لـGemini قبل أول فحص.
abstract class DisclosureStore {
  Future<bool> accepted();
  Future<void> accept();
}

class PrefsDisclosureStore implements DisclosureStore {
  static const key = 'disclosure_accepted';
  @override
  Future<bool> accepted() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> accept() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, true);
    } catch (_) {}
  }
}

final disclosureStoreProvider = Provider<DisclosureStore>((ref) => PrefsDisclosureStore());
