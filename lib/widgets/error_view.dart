import 'package:flutter/material.dart';
import '../widgets/adaptive/adaptive.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onRelogin;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.onRelogin,
  });

  @override
  Widget build(BuildContext context) {
    final isCf = message.contains('Cloudflare') ||
        message.contains('cloudflare') ||
        message.contains('challenge') ||
        message.contains('DDoS protection') ||
        message.contains('re-login');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCf ? Icons.shield_outlined : Icons.error_outline,
              color: isCf
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (isCf && onRelogin != null)
              AdaptiveButton(
                label: 'Re-login',
                onPressed: onRelogin,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login, size: 18),
                    SizedBox(width: 8),
                    Text('Re-login'),
                  ],
                ),
              ),
            if (isCf && onRelogin != null) const SizedBox(height: 12),
            if (onRetry != null)
              AdaptiveButton(
                label: 'Retry',
                onPressed: onRetry,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Retry'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
