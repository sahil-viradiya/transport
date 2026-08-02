import 'package:flutter/material.dart';

import '../app/core/theme/app_colors.dart';
import 'app_text.dart';

/// Consistent full-page loading state for feature views.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            if (message != null) ...[
              const SizedBox(height: 12),
              AppText(message!, style: AppTextStyle.bodyMedium),
            ],
          ],
        ),
      );
}

/// Shared empty state. The feature provides its own localized copy and action.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              AppText(title,
                  style: AppTextStyle.bodyLarge,
                  fontWeight: FontWeight.w600,
                  textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 6),
                AppText(message!,
                    style: AppTextStyle.bodyMedium,
                    color: AppColors.textSecondary,
                    textAlign: TextAlign.center),
              ],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}

/// Shared recoverable-error state. Copy and retry behavior stay feature-owned.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) => AppEmptyView(
        title: title,
        message: message,
        icon: Icons.error_outline_rounded,
        action: onRetry == null
            ? null
            : OutlinedButton(onPressed: onRetry, child: Text(retryLabel ?? '')),
      );
}
