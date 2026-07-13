import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_sizes.dart';
import 'custom_button.dart';
import 'star_rating.dart';

Future<bool> showRatingSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required Future<String?> Function(int stars, String? comment) onSubmit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: _RatingSheetContent(title: title, subtitle: subtitle, onSubmit: onSubmit),
    ),
  );
  return result ?? false;
}

class _RatingSheetContent extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<String?> Function(int stars, String? comment) onSubmit;

  const _RatingSheetContent({
    required this.title,
    required this.subtitle,
    required this.onSubmit,
  });

  @override
  State<_RatingSheetContent> createState() => _RatingSheetContentState();
}

class _RatingSheetContentState extends State<_RatingSheetContent> {
  int _stars = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() => _error = 'Tap a star to rate.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final comment = _commentController.text.trim();
    final error = await widget.onSubmit(_stars, comment.isEmpty ? null : comment);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.paddingL,
        AppSizes.spacing20,
        AppSizes.paddingL,
        AppSizes.paddingL + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSizes.spacing20),
            decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(2)),
          ),
          Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.spacing24),
          Center(
            child: StarRating(
              value: _stars,
              onChanged: (v) => setState(() {
                _stars = v;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: AppSizes.spacing20),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add a comment (optional)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSizes.spacing8),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: AppSizes.spacing24),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Skip',
                  outlined: true,
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: CustomButton(
                  text: 'Submit',
                  loading: _submitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}