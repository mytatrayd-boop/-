import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../domain/ports/incoming_link_source.dart';

/// تنفيذ [IncomingLinkSource] عبر receive_sharing_intent (D15).
class ReceiveSharingLinkSource implements IncomingLinkSource {
  ReceiveSharingLinkSource([ReceiveSharingIntent? api])
      : _api = api ?? ReceiveSharingIntent.instance;

  final ReceiveSharingIntent _api;

  static String? _text(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        return f.path;
      }
    }
    return null;
  }

  @override
  Future<String?> initialText() async {
    final text = _text(await _api.getInitialMedia());
    // يمنع إعادة تسليم نفس النية عند إعادة إنشاء الواجهة.
    await _api.reset();
    return text;
  }

  @override
  Stream<String> get texts => _api
      .getMediaStream()
      .map(_text)
      .where((t) => t != null)
      .cast<String>();
}
