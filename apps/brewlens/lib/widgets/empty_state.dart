import 'package:flutter/material.dart';

/// حالة فارغة (DESIGN §1.4): أيقونة 64، عنوان، وزر رئيسي اختياري.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// حالة خطأ عامة: أيقونة، نص، «إعادة المحاولة».
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.retryLabel, required this.onRetry});

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ),
        ),
      );
}
