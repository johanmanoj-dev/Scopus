import 'package:flutter/material.dart';
import '../../core/themes/app_theme.dart';
import '../../core/errors/app_exception.dart';

class RiverpodErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final String? customMessage;

  const RiverpodErrorState({
    super.key,
    required this.error,
    required this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Parse error for user-friendly display
    String displayMessage = 'An unexpected error occurred.';
    if (error is AppException) {
      displayMessage = (error as AppException).message;
    } else {
      displayMessage = error.toString();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconForError(error),
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            if (customMessage != null) ...[
              Text(
                customMessage!,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              displayMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.surfaceVariant,
                foregroundColor: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForError(Object error) {
    if (error is NetworkException) return Icons.wifi_off_outlined;
    if (error is FirestoreException) return Icons.cloud_off_outlined;
    if (error is AuthException) return Icons.lock_outline;
    return Icons.error_outline;
  }
}
