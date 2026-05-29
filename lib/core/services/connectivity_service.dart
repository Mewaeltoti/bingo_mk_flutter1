import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Singleton that exposes a broadcast stream of connectivity status.
/// True = online, False = offline.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription? _sub;

  Stream<bool> get onlineStream => _controller.stream;

  /// Call once from main() before runApp().
  void init() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      _controller.add(isOnline);
    });
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
