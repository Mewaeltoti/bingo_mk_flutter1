import 'package:flutter/material.dart';
import 'loading_widgets.dart';

class LoadingDialog extends StatelessWidget {
  final String message;

  const LoadingDialog({
    super.key,
    this.message = 'Processing...',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1B2A),
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.25), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSpinner(size: 48, strokeWidth: 4, color: Color(0xFFD4AF37)),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'እባክዎ መተግበሪያውን አይዝጉት',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Color(0xFFB0BEC5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Guards against stacked dialogs: rapid state updates (e.g. during
  // registerAllPending) can trigger multiple show() calls before any hide().
  // Without this flag, each call pushes a new dialog route — hide() then only
  // pops one, leaving a ghost dialog covering the screen forever.
  static bool _isShowing = false;
  static BuildContext? _activeContext;

  static void show(BuildContext context, {String message = 'Processing...'}) {
    if (_isShowing) return;
    _isShowing = true;
    _activeContext = context;

    showGeneralDialog(
      context: context,
      barrierDismissible: true, // Allow dismiss on tap outside
      barrierLabel: 'Loading',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => LoadingDialog(message: message),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    ).then((_) {
      // Reset variables when dialog is closed (either by tapping outside or manually)
      _isShowing = false;
      _activeContext = null;
    });

    // AUTO-TIMEOUT: If processing takes more than 15 seconds, dismiss it
    // so the user never gets stuck with a spinning screen forever.
    final capturedContext = context;
    Future.delayed(const Duration(seconds: 15), () {
      if (_isShowing && _activeContext == capturedContext) {
        hide(capturedContext);
        ScaffoldMessenger.of(capturedContext).showSnackBar(
          const SnackBar(
            content: Text("የጥያቄው ጊዜ አልቋል (Timeout)። እባክዎ በድጋሚ ይሞክሩ።"),
            backgroundColor: Color(0xFF93000A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  static void hide(BuildContext context) {
    if (!_isShowing) return;
    _isShowing = false;
    _activeContext = null;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}