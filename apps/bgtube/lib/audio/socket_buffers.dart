import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// حدود مخازن المقابس في النواة لمسار الصوت (D26). بدونها يكبر مخزن الاستقبال
/// تلقائياً (حتى عشرات MB على بعض الأنظمة) فيُنزَّل من الأصل أكثر بكثير مما
/// يقرأه المشغّل حتى مع الضغط العكسي. 128KB (لينكس يضاعفها) تكفي نحو 5MB/ث عند 50 م.ث،
/// والصوت نحو 16KB/ث.
const socketBufferBytes = 128 * 1024;

int? get _soSndBuf => switch (Platform.operatingSystem) {
      'linux' || 'android' => 7,
      'macos' || 'ios' || 'windows' => 0x1001,
      _ => null,
    };

int? get _soRcvBuf => switch (Platform.operatingSystem) {
      'linux' || 'android' => 8,
      'macos' || 'ios' || 'windows' => 0x1002,
      _ => null,
    };

/// يضبط SO_RCVBUF/SO_SNDBUF. أفضل جهد: الفشل يُتجاهل (يبقى السلوك الافتراضي).
void limitSocketBuffers(Socket s, {int? receive, int? send}) {
  void set(int? name, int? bytes) {
    if (name == null || bytes == null) return;
    try {
      s.setRawOption(RawSocketOption.fromInt(RawSocketOption.levelSocket, name, bytes));
    } catch (_) {}
  }

  set(_soRcvBuf, receive);
  set(_soSndBuf, send);
}

/// يقرأ SO_RCVBUF/SO_SNDBUF الفعلية (للاختبار؛ لينكس يضاعف القيمة المطلوبة).
({int? receive, int? send}) readSocketBuffers(Socket s) {
  int? get(int? name) {
    if (name == null) return null;
    try {
      final b = s.getRawOption(RawSocketOption(RawSocketOption.levelSocket, name, Uint8List(4)));
      return b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24;
    } catch (_) {
      return null;
    }
  }

  return (receive: get(_soRcvBuf), send: get(_soSndBuf));
}

/// مصنع اتصالات لـHttpClient يحدّ مخزن الاستقبال قبل أي بيانات، ثم يلفّ TLS
/// بنفسه لروابط https (كما يفعل HttpClient افتراضياً عبر SecureSocket).
///
/// [context] للاختبار فقط (شهادة محلية)؛ الافتراضي جذور النظام كما في HttpClient.
Future<ConnectionTask<Socket>> Function(Uri, String?, int?) limitedConnectionFactory({
  int receiveBytes = socketBufferBytes,
  SecurityContext? context,
}) =>
    (uri, proxyHost, proxyPort) async {
      final task = await Socket.startConnect(proxyHost ?? uri.host, proxyPort ?? uri.port);
      final socket = task.socket.then<Socket>((s) {
        limitSocketBuffers(s, receive: receiveBytes);
        // عبر وكيل HTTP: HttpClient ينشئ النفق وTLS بنفسه على المقبس العادي.
        if (uri.scheme == 'https' && proxyHost == null) return SecureSocket.secure(s, host: uri.host, context: context);
        return s;
      });
      return ConnectionTask.fromSocket(socket, task.cancel);
    };

/// ServerSocket يحدّ مخزن الإرسال لكل اتصال مقبول، لاستعماله مع
/// [HttpServer.listenOn]: حين يتوقف المشغّل عن القراءة لا يتكدس إلا قليل.
class SendLimitedServerSocket extends StreamView<Socket> implements ServerSocket {
  SendLimitedServerSocket(this._inner, {int sendBytes = socketBufferBytes})
      : super(_inner.map((s) {
          limitSocketBuffers(s, send: sendBytes);
          return s;
        }));

  final ServerSocket _inner;

  @override
  int get port => _inner.port;
  @override
  InternetAddress get address => _inner.address;
  @override
  Future<ServerSocket> close() async {
    await _inner.close();
    return this;
  }
}
