import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_sizes.dart';
import 'custom_button.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingL,
        AppSizes.spacing32,
        AppSizes.paddingL,
        AppSizes.spacing40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.primarySoft, AppColors.primarySoft.withValues(alpha: 0.0)],
              ),
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacing20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSizes.spacing24),
            CustomButton(
              text: actionLabel!,
              onPressed: onAction,
              expand: false,
              height: AppSizes.buttonHeightS,
            ),
          ],
        ],
      ),
    );
  }
}