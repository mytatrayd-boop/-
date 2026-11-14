import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/data/camera/camera_preview_source.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

void main() {
  testWidgets('open يفتح الكاميرا ويعرض Texture بحجم المصدر مقصوصاً cover', (t) async {
    final rec = FakeRihlaRecorder();
    final src = NativeCameraPreviewSource(rec, quality: RecorderQuality.p1080);
    await src.open();
    expect(rec.cameraOpen, isTrue);
    expect(rec.openedQuality, RecorderQuality.p1080);
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 400, height: 360, child: Builder(builder: src.buildPreview)),
      ),
    );
    final tex = t.widget<Texture>(find.byType(Texture));
    expect(tex.textureId, 1);
    expect(t.widget<FittedBox>(find.byType(FittedBox)).fit, BoxFit.cover);
    expect(t.getSize(find.byType(Texture)), const Size(1920, 1080));
    await src.close();
    expect(rec.cameraOpen, isFalse);
  });

  test('فشل الأصلي يتحول إلى CameraOpenException', () async {
    final rec = FakeRihlaRecorder(openFailure: const RecorderException('camera_unavailable', 'busy'));
    expect(NativeCameraPreviewSource(rec).open(), throwsA(isA<CameraOpenException>()));
  });

  test('بدون إضافة أصلية (Linux) يفشل open بصدق', () async {
    final src = NativeCameraPreviewSource(MethodChannelRihlaRecorder());
    expect(src.open(), throwsA(isA<CameraOpenException>()));
  });

  testWidgets('قبل open لا شيء يُعرض', (t) async {
    final src = NativeCameraPreviewSource(FakeRihlaRecorder());
    await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Builder(builder: src.buildPreview)));
    expect(find.byType(Texture), findsNothing);
  });
}
