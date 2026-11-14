import 'package:flutter/widgets.dart';

import 'camera_preview_source.dart';

class FakeCameraPreviewSource implements CameraPreviewSource {
  FakeCameraPreviewSource({this.failTimes = 0});

  /// عدد مرات فشل open قبل أن ينجح.
  int failTimes;
  int openCalls = 0;
  int closeCalls = 0;
  bool isOpen = false;

  static const previewKey = ValueKey('fake-camera-preview');

  @override
  Future<void> open() async {
    openCalls++;
    if (failTimes > 0) {
      failTimes--;
      throw const CameraOpenException('busy');
    }
    isOpen = true;
  }

  @override
  Future<void> close() async {
    closeCalls++;
    isOpen = false;
  }

  @override
  Widget buildPreview(BuildContext context) => const ColoredBox(
    key: previewKey,
    color: Color(0xFF333333),
    child: SizedBox.expand(),
  );
}
