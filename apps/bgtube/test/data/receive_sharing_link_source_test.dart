import 'dart:async';

import 'package:bgtube/data/incoming/receive_sharing_link_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

SharedMediaFile text(String t) =>
    SharedMediaFile(path: t, type: SharedMediaType.text);

void main() {
  test('initial text is delivered once only (reset consumes it)', () async {
    ReceiveSharingIntent.setMockValues(
      initialMedia: [text('https://youtu.be/dQw4w9WgXcQ')],
      mediaStream: const Stream.empty(),
    );
    final s = ReceiveSharingLinkSource();
    expect(await s.initialText(), 'https://youtu.be/dQw4w9WgXcQ');
    expect(await s.initialText(), isNull);
  });

  test('stream maps text items and ignores non-text', () async {
    final ctl = StreamController<List<SharedMediaFile>>();
    ReceiveSharingIntent.setMockValues(
      initialMedia: [],
      mediaStream: ctl.stream,
    );
    final s = ReceiveSharingLinkSource();
    final got = <String>[];
    final sub = s.texts.listen(got.add);
    ctl.add([SharedMediaFile(path: '/x.jpg', type: SharedMediaType.image)]);
    ctl.add([text('a')]);
    await Future<void>.delayed(Duration.zero);
    expect(got, ['a']);
    await sub.cancel();
    await ctl.close();
  });
}
