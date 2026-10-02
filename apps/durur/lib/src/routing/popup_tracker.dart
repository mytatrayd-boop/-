import 'package:flutter/widgets.dart';

/// يعدّ المسارات المنبثقة المفتوحة (ورقة سفلية، حوار، منتقي التاريخ) في
/// موجّه التطبيق، لتنتظر رسالة «حُدّثت البيانات» حتى تُغلق (DESIGN 8.7).
class PopupRouteTracker extends NavigatorObserver {
  PopupRouteTracker({required this.onAllClosed});

  /// يُنادى عند إغلاق آخر مسار منبثق.
  final VoidCallback onAllClosed;

  int _open = 0;

  bool get hasPopup => _open > 0;

  void _closed(Route<dynamic>? route) {
    if (route is! PopupRoute) return;
    if (_open > 0) _open--;
    if (_open == 0) onAllClosed();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _open++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _closed(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _closed(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PopupRoute) _open++;
    _closed(oldRoute);
  }
}
