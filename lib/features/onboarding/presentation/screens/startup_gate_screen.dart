import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/screens/role_gate_screen.dart';
import '../../view_model/onboarding_view_model.dart';
import 'onboarding_screen.dart';

class StartupGateScreen extends ConsumerWidget {
  const StartupGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSeenOnboarding = ref.watch(hasSeenOnboardingProvider);

    if (!hasSeenOnboarding) return const OnboardingScreen();
    return const RoleGateScreen();
  }
}
