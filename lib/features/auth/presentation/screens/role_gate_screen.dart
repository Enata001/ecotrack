import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/enums.dart';
import '../../../../shared/app_logo.dart';
import 'login_screen.dart';

class RoleGateScreen extends ConsumerWidget {
  const RoleGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      loading: () => const _SplashLoader(),
      error: (_, _) => const LoginScreen(),
      data: (firebaseUser) {
        if (firebaseUser == null) return const LoginScreen();
        return _RoleResolver(uid: firebaseUser.uid);
      },
    );
  }
}

class _RoleResolver extends ConsumerStatefulWidget {
  final String uid;
  const _RoleResolver({required this.uid});

  @override
  ConsumerState<_RoleResolver> createState() => _RoleResolverState();
}

class _RoleResolverState extends ConsumerState<_RoleResolver> {
  AppUser? _appUser;
  bool _loaded = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await ref.read(authRepositoryProvider).fetchAppUser(widget.uid);
    if (!mounted) return;
    setState(() {
      _appUser = user;
      _loaded = true;
    });

    if (user != null && user.notificationsEnabled) {
      _registerFcmToken(user.role);
    }
  }

  Future<void> _registerFcmToken(UserRole role) async {
    try {
      final fcm = ref.read(fcmServiceProvider);
      final granted = await fcm.requestPermission();
      if (!granted) return;

      final token = await fcm.getToken();
      if (token == null) return;

      if (mounted) {
        await ref.read(authRepositoryProvider).registerFcmToken(
          uid: widget.uid,
          role: role,
          token: token,
        );
      }
    } catch (e, st) {
      debugPrint('FCM registration failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _SplashLoader();

    final user = _appUser;
    if (user == null) return const LoginScreen();

    if (!_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = user.role == UserRole.collector
            ? RouteNames.collectorHome
            : RouteNames.userHome;
        AppRouter.pushAndRemoveUntil(route);
      });
    }

    return const _SplashLoader();
  }
}

class _SplashLoader extends StatefulWidget {
  const _SplashLoader();

  @override
  State<_SplashLoader> createState() => _SplashLoaderState();
}

class _SplashLoaderState extends State<_SplashLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDeeper,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.ambientGlow)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.95, end: 1.06).animate(
                    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const AppLogo(size: 96),
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}