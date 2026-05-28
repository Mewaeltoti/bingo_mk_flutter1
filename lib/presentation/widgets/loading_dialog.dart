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
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSpinner(size: 60, strokeWidth: 5),
            const SizedBox(height: 32),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please do not close the app',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
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

  static void show(BuildContext context, {String message = 'Processing...'}) {
    if (_isShowing) return;
    _isShowing = true;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
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
    ).whenComplete(() {
      // Reset the flag when the dialog is dismissed by any means (hide, back
      // button, or system navigation) so future calls work correctly.
      _isShowing = false;
    });
  }

  static void hide(BuildContext context) {
    if (!_isShowing) return;
    _isShowing = false;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}