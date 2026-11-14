import 'dart:async';

import 'network_status_source.dart';

class FakeNetworkStatusSource implements NetworkStatusSource {
  FakeNetworkStatusSource({this.online = true});
  bool online;
  final _ctrl = StreamController<bool>.broadcast();

  void set(bool v) {
    online = v;
    _ctrl.add(v);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> onlineChanges() => _ctrl.stream;
}
