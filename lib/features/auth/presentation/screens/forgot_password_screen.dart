import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    Helpers.hideKeyboard(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final result = await ref
        .read(authRepositoryProvider)
        .resetPassword(_emailController.text.trim());

    if (!mounted) return;
    setState(() => _submitting = false);

    result.map(
      onSuccess: (_) => setState(() => _sent = true),
      onError: (error) {
        if (error.code == 'user-not-found') {
          setState(() => _sent = true);
        } else {
          context.showSnack(error.message, isError: true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background, ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            child: AnimatedSwitcher(
              duration: AppSizes.durationMedium,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: _sent
                  ? _SentState(key: const ValueKey('sent'), email: _emailController.text.trim())
                  : _buildForm(context, key: const ValueKey('form')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, {Key? key}) {
    return Form(
      key: _formKey,
      child: ListView(
        key: key,
        children: [
          const SizedBox(height: AppSizes.spacing8),
          const SizedBox(height: AppSizes.spacing24),
          Text('Reset your password', style: context.textTheme.headlineSmall),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            "Enter the email on your account and we'll send you a link to "
                'reset your password.',
            style: context.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.spacing32),
          CustomTextField(
            label: 'Email',
            hint: 'you@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: Validators.email,
            prefix: const Icon(Icons.mail_outline_rounded, size: 20),
          ),
          const SizedBox(height: AppSizes.spacing32),
          CustomButton(
            text: 'Send reset link',
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _SentState extends StatelessWidget {
  final String email;
  const _SentState({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.success.withValues(alpha: 0.16), AppColors.success.withValues(alpha: 0.0)],
              ),
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacing24),
          Text('Check your email', style: context.textTheme.headlineSmall),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            email.isEmpty
                ? "If an account exists for that address, we've sent a reset link."
                : "If an account exists for $email, we've sent a reset link.",
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}