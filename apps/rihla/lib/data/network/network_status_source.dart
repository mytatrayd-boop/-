import 'package:connectivity_plus/connectivity_plus.dart';

/// واجهة مجردة لحالة الاتصال بالإنترنت (للرسالة "بلا إنترنت: الخريطة لن تتحدث").
abstract class NetworkStatusSource {
  Future<bool> isOnline();
  Stream<bool> onlineChanges();
}

/// التنفيذ الحقيقي (connectivity_plus). ملاحظة: يخبر بوجود شبكة لا بوصول
/// الإنترنت فعلاً. لم يُجرَّب على جهاز.
class ConnectivityNetworkStatusSource implements NetworkStatusSource {
  const ConnectivityNetworkStatusSource();

  static bool _online(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async =>
      _online(await Connectivity().checkConnectivity());

  @override
  Stream<bool> onlineChanges() =>
      Connectivity().onConnectivityChanged.map(_online);
}
