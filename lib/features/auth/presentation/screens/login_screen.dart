import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/app_logo.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../view_model/auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authViewModelProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (!success) {
      final error = ref.read(authViewModelProvider).error;
      context.showSnack(error ?? 'Sign in failed', isError: true);
      return;
    }

    final appUser = ref.read(authViewModelProvider).appUser;
    if (appUser != null) {
      final route = appUser.role == UserRole.collector
          ? RouteNames.collectorHome
          : RouteNames.userHome;
      AppRouter.pushAndRemoveUntil(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authViewModelProvider.select((s) => s.loading));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        extendBody: true,
        // extendBodyBehindAppBar: true,

        // appBar: AppBar(
        //   elevation: 0,
        //   scrolledUnderElevation: 0,
        //   forceMaterialTransparency: true,
        //   backgroundColor: AppColors.background,
        //   automaticallyImplyLeading: false,
        // ),

        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -100,
                right: -70,
                child: _AmbientBlob(color: AppColors.primary, size: 260),
              ),
              Positioned(
                bottom: -60,
                left: -80,
                child: _AmbientBlob(color: AppColors.accent, size: 220),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      const SizedBox(height: AppSizes.spacing24),
                      const AppLogo(size: 100),
                      const SizedBox(height: AppSizes.spacing32),
                      Text(
                        'Welcome back',
                        style: context.textTheme.displaySmall,
                      ),
                      const SizedBox(height: AppSizes.spacing8),
                      Text(
                        'Sign in to request or fulfill a pickup',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacing32),
                      CustomTextField(
                        label: 'Email',
                        hint: 'you@example.com',
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        validator: Validators.email,
                        prefix: const Icon(
                          Icons.mail_outline_rounded,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacing16),
                      CustomTextField(
                        label: 'Password',
                        hint: 'Enter your password',
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) =>
                            Validators.required(v, fieldName: 'Password'),
                        prefix: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                        ),
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.grey500,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              AppRouter.push(RouteNames.forgotPassword),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacing16),
                      CustomButton(
                        text: 'Sign In',
                        loading: loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSizes.spacing24),
                      Center(
                        child: TextButton(
                          onPressed: () => AppRouter.push(RouteNames.signup),
                          child: RichText(
                            text: TextSpan(
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              children: const [
                                TextSpan(text: "Don't have an account? "),
                                TextSpan(
                                  text: 'Sign up',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
