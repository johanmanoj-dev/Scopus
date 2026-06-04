import 'package:flutter/material.dart';
import 'app_exception.dart';
import '../../core/services/google_auth_service.dart';

/// Global error presentation layer for Scopus.
///
/// Services (Drive, Firestore, Sync) call [AppErrorHandler.show] to
/// display user-friendly SnackBars without needing a BuildContext.
///
/// Usage:
///   1. Assign [scaffoldMessengerKey] to MaterialApp.scaffoldMessengerKey
///   2. Call AppErrorHandler.show(exception) from any service or widget
class AppErrorHandler {
  AppErrorHandler._();

  /// Attach this key to [MaterialApp.scaffoldMessengerKey].
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // ── Public API ───────────────────────────────────────────────────

  /// Shows a themed SnackBar for the given [AppException].
  /// Picks color and icon based on exception type.
  static void show(AppException exception) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return; // App not yet mounted

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_iconFor(exception), color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                exception.message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: _colorFor(exception),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white70,
          onPressed: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// Shows a plain message (for non-AppException errors).
  static void showMessage(String message, {bool isError = true}) {
    show(AppException(message, code: isError ? 'generic-error' : 'info'));
  }

  /// Shows a Drive session lost SnackBar with a one-click [Reconnect] action.
  ///
  /// When the user taps Reconnect, [GoogleAuthService.reconnectDriveOnly]
  /// is called (browser OAuth, no Firebase sign-out), then [onReconnected]
  /// is invoked so the caller can retry the failed operation.
  static void showDriveReconnect({VoidCallback? onReconnected}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Drive session lost. Tap Reconnect to restore access.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A73E8), // Google blue
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 12),
        action: SnackBarAction(
          label: 'Reconnect',
          textColor: Colors.white,
          onPressed: () async {
            messenger.hideCurrentSnackBar();
            try {
              await GoogleAuthService().reconnectDriveOnly();
              onReconnected?.call();
            } catch (e) {
              showMessage('Reconnect failed: $e');
            }
          },
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static Color _colorFor(AppException e) {
    if (e is DriveException) return const Color(0xFF1A73E8);    // Google blue
    if (e is FirestoreException) return const Color(0xFFFF6D00); // Firebase orange
    if (e is AuthException) return const Color(0xFFB71C1C);      // dark red
    if (e is NetworkException) return const Color(0xFF455A64);   // blue grey
    return const Color(0xFF323232);                               // default dark
  }

  static IconData _iconFor(AppException e) {
    if (e is DriveException) return Icons.cloud_off;
    if (e is FirestoreException) return Icons.storage_outlined;
    if (e is AuthException) return Icons.lock_outline;
    if (e is NetworkException) return Icons.wifi_off;
    return Icons.error_outline;
  }
}
