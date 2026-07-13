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
import '../../../../shared/widgets/tap_scale.dart';
import '../../view_model/auth_view_model.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  UserRole _role = UserRole.user;
  VehicleType _vehicleType = VehicleType.van;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authViewModelProvider.notifier).signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _role,
      vehicleType: _role == UserRole.collector ? _vehicleType : null,
    );

    if (!mounted) return;

    if (!success) {
      final error = ref.read(authViewModelProvider).error;
      context.showSnack(error ?? 'Sign up failed', isError: true);
      return;
    }

    // See LoginScreen._submit for why this navigates explicitly instead of
    // relying on the background RoleGateScreen auth-state listener.
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
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSizes.paddingL,
                0,
                AppSizes.paddingL,
                AppSizes.paddingL,
              ),
              children: [
                const AppLogo(size: 90),
                const SizedBox(height: AppSizes.spacing20),
                Text('Create your account', style: context.textTheme.headlineSmall),
                const SizedBox(height: AppSizes.spacing4),
                Text(
                  'Takes less than a minute',
                  style: context.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.spacing24),
                Text("I'm signing up as a", style: context.textTheme.titleMedium),
                const SizedBox(height: AppSizes.spacing12),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.person_outline_rounded,
                        title: 'User',
                        subtitle: 'Request pickups',
                        selected: _role == UserRole.user,
                        onTap: () => setState(() => _role = UserRole.user),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.local_shipping_outlined,
                        title: 'Collector',
                        subtitle: 'Fulfill pickups',
                        selected: _role == UserRole.collector,
                        onTap: () => setState(() => _role = UserRole.collector),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing24),
                CustomTextField(
                  label: 'Full name',
                  controller: _nameController,
                  focusNode: _nameFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                  validator: (v) => Validators.required(v, fieldName: 'Name'),
                  prefix: const Icon(Icons.badge_outlined, size: 20),
                ),
                const SizedBox(height: AppSizes.spacing16),
                CustomTextField(
                  label: 'Email',
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  validator: Validators.email,
                  prefix: const Icon(Icons.mail_outline_rounded, size: 20),
                ),
                const SizedBox(height: AppSizes.spacing16),
                CustomTextField(
                  label: 'Password',
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                  validator: Validators.password,
                  prefix: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.grey500,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing16),
                CustomTextField(
                  label: 'Confirm password',
                  controller: _confirmController,
                  focusNode: _confirmFocus,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      Validators.confirmPassword(v, _passwordController.text),
                  prefix: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.grey500,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                if (_role == UserRole.collector) ...[
                  const SizedBox(height: AppSizes.spacing20),
                  Text('Vehicle type', style: context.textTheme.titleMedium),
                  const SizedBox(height: AppSizes.spacing12),
                  Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: VehicleType.values.map((v) {
                      final selected = _vehicleType == v;
                      return ChoiceChip(
                        label: Text(v.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _vehicleType = v),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: AppSizes.spacing32),
                CustomButton(
                  text: 'Create account',
                  loading: loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSizes.spacing16),
                Center(
                  child: TextButton(
                    onPressed: () => AppRouter.pop(),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppSizes.durationFast,
        padding: const EdgeInsets.symmetric(
          vertical: AppSizes.spacing20,
          horizontal: AppSizes.paddingM,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ]
              : null,
        ),
        child: Stack(
          children: [
            if (selected)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                ),
              ),
            Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.heroGradient : null,
                    color: selected ? null : AppColors.grey50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : AppColors.grey500,
                    size: 22,
                  ),
                ),
                const SizedBox(height: AppSizes.spacing12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.spacing4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}