import 'dart:async';

/// Abstraction so tests can fake online/offline without platform channels.
abstract class ConnectivityMonitor {
  Stream<bool> get online;

  Future<bool> get isOnline;

  void dispose();
}

class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor({bool online = true}) : _online = online;

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Stream<bool> get online => _controller.stream;

  @override
  Future<bool> get isOnline async => _online;

  @override
  void dispose() {
    _controller.close();
  }
}
