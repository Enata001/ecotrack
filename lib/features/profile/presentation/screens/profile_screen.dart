import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_args.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/tap_scale.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  AppUser? _user;
  bool _loading = true;
  bool _signingOut = false;
  bool _updatingNotifications = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    final user =
    uid == null ? null : await ref.read(authRepositoryProvider).fetchAppUser(uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    final user = _user;
    if (user == null) return;
    await AppRouter.push(RouteNames.editProfile, arguments: EditProfileArgs(user: user));
    if (!mounted) return;
    _loadUser();
  }

  Future<void> _toggleNotifications(bool enabled) async {
    final user = _user;
    if (user == null) return;

    setState(() => _updatingNotifications = true);

    String? token;
    if (enabled) {
      final fcm = ref.read(fcmServiceProvider);
      final granted = await fcm.requestPermission();
      token = granted ? await fcm.getToken() : null;
    }

    final result = await ref.read(authRepositoryProvider).setNotificationsEnabled(
      uid: user.uid,
      role: user.role,
      enabled: enabled,
      fcmToken: token,
    );

    if (!mounted) return;
    setState(() => _updatingNotifications = false);

    result.map(
      onSuccess: (_) {
        setState(() => _user = user.copyWith(notificationsEnabled: enabled));
      },
      onError: (error) => context.showSnack(error.message, isError: true),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll need to sign in again to use the app."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _signingOut = true);
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;

    AppRouter.pushAndRemoveUntil(RouteNames.roleGate);
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    final result = await ref.read(authRepositoryProvider).deleteAccount();
    if (!mounted) return;

    result.map(
      onSuccess: (_) async {
        await ref.read(authRepositoryProvider).signOut();
        if (!mounted) return;
        AppRouter.pushAndRemoveUntil(RouteNames.roleGate);
      },
      onError: (error) {
        setState(() => _deleting = false);
        context.showSnack(error.message, isError: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: _loading
            ? const Padding(
          padding: EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            children: [
              ShimmerBox(height: 88, width: 88, borderRadius: 44),
              SizedBox(height: AppSizes.spacing16),
              ShimmerBox(height: 20, width: 160),
            ],
          ),
        )
            : _user == null
            ? Center(
          child: Text(
            "Couldn't load your profile.",
            style: context.textTheme.bodyMedium,
          ),
        )
            : _buildContent(_user!),
      ),
    );
  }

  Widget _buildContent(AppUser user) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      children: [
        Center(
          child: Column(
            children: [
              TapScale(
                onTap: _editProfile,
                child: Stack(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(color: AppColors.grey50, shape: BoxShape.circle),
                        child: user.photoUrl != null
                            ? Image.network(user.photoUrl!, fit: BoxFit.cover)
                            : const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.grey300,
                          size: 40,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2.5),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 13, color: AppColors.grey900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.spacing16),
              Text(
                user.name.isEmpty ? 'No name set' : user.name,
                style: context.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSizes.spacing4),
              Text(
                user.email,
                style: context.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSizes.spacing12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing12,
                  vertical: AppSizes.spacing4,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
                ),
                child: Text(
                  user.role == UserRole.collector ? 'Collector' : 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: AppSizes.fontS,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacing24),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            boxShadow: [
              BoxShadow(color: AppColors.grey900.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              _ProfileTile(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: (user.phone == null || user.phone!.isEmpty) ? 'Not set' : user.phone!,
              ),
              const Divider(height: 1, indent: AppSizes.paddingM, endIndent: AppSizes.paddingM),
              if (user.role == UserRole.collector) ...[
                _ProfileTile(
                  icon: Icons.local_shipping_outlined,
                  label: 'Vehicle type',
                  value: user.vehicleType?.label ?? 'Not set',
                ),
                const Divider(height: 1, indent: AppSizes.paddingM, endIndent: AppSizes.paddingM),
              ],
              _ProfileTile(
                icon: Icons.star_rounded,
                iconColor: AppColors.accentDark,
                label: 'Rating',
                value: user.rating.toStringAsFixed(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacing16),
        if (user.role == UserRole.user) ...[
          TapScale(
            onTap: () => AppRouter.push(RouteNames.savedAddresses),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                boxShadow: [
                  BoxShadow(color: AppColors.grey900.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                    child: const Icon(Icons.bookmark_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  const Expanded(
                    child: Text('Saved addresses', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.grey300),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacing16),
          TapScale(
            onTap: () => AppRouter.push(RouteNames.scheduledPickups),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                boxShadow: [
                  BoxShadow(color: AppColors.grey900.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                    child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  const Expanded(
                    child: Text('Scheduled pickups', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.grey300),
                ],
              ),
            ),
          ),
        ],
          const SizedBox(height: AppSizes.spacing16),
        Container(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            boxShadow: [
              BoxShadow(color: AppColors.grey900.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: AppSizes.spacing12),
              const Expanded(
                child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              _updatingNotifications
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Switch(
                value: user.notificationsEnabled,
                activeThumbColor: AppColors.primary,
                thumbColor: WidgetStatePropertyAll(Colors.white),
                onChanged: _toggleNotifications,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacing24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _signingOut ? null : _confirmSignOut,
            icon: _signingOut
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.logout_rounded, color: AppColors.error),
            label: const Text('Sign out', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
          ),
        ),
        const SizedBox(height: AppSizes.spacing32),
        Center(
          child: TextButton(
            onPressed: _deleting ? null : _confirmDeleteAccount,
            child: _deleting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text(
              'Delete account',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes your account and profile data. This '
                "cannot be undone. Type DELETE below to confirm.",
          ),
          const SizedBox(height: AppSizes.spacing12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'DELETE'),
            onChanged: (value) => setState(() => _canDelete = value.trim() == 'DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canDelete ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _ProfileTile({
    required this.icon,
    this.iconColor = AppColors.primary,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}