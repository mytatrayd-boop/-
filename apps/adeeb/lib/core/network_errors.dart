import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// هل الخطأ انقطاع اتصال (لا رد من الخادم)؟ نكتشف الانقطاع من فشل الطلب
/// لا من حزمة اتصال (ARCHITECTURE §3).
bool isNetworkError(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is HandshakeException ||
    error is HttpException ||
    error is http.ClientException;
