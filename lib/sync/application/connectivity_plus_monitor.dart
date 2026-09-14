import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_monitor.dart';

/// Production connectivity — excluded from coverage gate (platform channels).
class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _controller.add(_isOnline(results));
    });
  }

  final Connectivity _connectivity;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  Stream<bool> get online => _controller.stream;

  @override
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
