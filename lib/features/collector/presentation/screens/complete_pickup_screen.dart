import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/rating_prompt_sheet.dart';

class CompletePickupScreen extends ConsumerStatefulWidget {
  final String requestId;
  const CompletePickupScreen({super.key, required this.requestId});

  @override
  ConsumerState<CompletePickupScreen> createState() => _CompletePickupScreenState();
}

class _CompletePickupScreenState extends ConsumerState<CompletePickupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  WasteType _wasteType = WasteType.general;
  bool _submitting = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    Helpers.hideKeyboard(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final result = await ref.read(requestRepositoryProvider).completePickup(
      requestId: widget.requestId,
      weightKg: double.parse(_weightController.text),
      wasteType: _wasteType,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.map(
      onSuccess: (_) async {
        Helpers.showToast(message: 'Pickup completed');
       if (mounted) {
          await showRatingSheet(
            context: context,
            title: 'Rate this customer',
            subtitle: 'How did this pickup go?',
            onSubmit: (stars, comment) async {
              final ratingResult = await ref.read(requestRepositoryProvider).submitRating(
                requestId: widget.requestId,
                stars: stars,
                comment: comment,
              );
              return ratingResult.map(onSuccess: (_) => null, onError: (e) => e.message);
            },
          );
        }
        if (mounted) AppRouter.pop();
      },
      onError: (error) => context.showSnack(error.message, isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Complete pickup')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const _StepLabel(number: 1, text: 'Confirm waste type'),
                  const SizedBox(height: AppSizes.spacing12),
                  Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: WasteType.values.map((type) {
                      return ChoiceChip(
                        label: Text(type.label),
                        selected: _wasteType == type,
                        onSelected: (_) => setState(() => _wasteType = type),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSizes.spacing28),
                  const _StepLabel(number: 2, text: 'Log the actual weight'),
                  const SizedBox(height: AppSizes.spacing12),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(color: AppColors.grey900.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
                          child: const Icon(Icons.scale_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: AppSizes.spacing16),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.center,
                          onFieldSubmitted: (_) => _submit(),
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1),
                          decoration: const InputDecoration(
                            hintText: '0.0',
                            suffixText: 'kg',
                            suffixStyle: TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Weight is required';
                            final parsed = double.tryParse(value);
                            if (parsed == null || parsed <= 0) return 'Enter a valid weight';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing32),
                  CustomButton(
                    text: 'Confirm completion',
                    icon: Icons.check_circle_rounded,
                    loading: _submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final int number;
  final String text;
  const _StepLabel({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
          child: Center(
            child: Text('$number', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: AppSizes.spacing8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
      ],
    );
  }
}