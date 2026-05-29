import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Wraps any child widget and shows a persistent "No internet connection"
/// banner at the top whenever the device goes offline.
/// Re-subscribes streams via [GameCubit.onAppResumed] are handled separately
/// (app lifecycle observer). This widget purely handles the UI indicator.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  late final AnimationController _animController;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    ConnectivityService.instance.onlineStream.listen((isOnline) {
      if (!mounted) return;
      setState(() => _isOnline = isOnline);
      if (isOnline) {
        _animController.reverse();
      } else {
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Banner slides down from the top when offline
        AnimatedBuilder(
          animation: _slideAnim,
          builder: (context, _) {
            if (_isOnline && _animController.isDismissed) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FractionalTranslation(
                translation: Offset(0, _slideAnim.value),
                child: Material(
                  color: Colors.transparent,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      color: const Color(0xFFB71C1C), // deep red
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'No internet connection',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!_isOnline)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
