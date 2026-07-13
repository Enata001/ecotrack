import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/local_storage_service.dart';

final hasSeenOnboardingProvider = Provider<bool>((ref) {
  return ref.watch(localStorageServiceProvider).getBool(
        LocalStorageKeys.hasSeenOnboarding,
      );
});

class OnboardingViewModel extends Notifier<void> {
  @override
  void build() {}

  Future<void> complete() async {
    await ref
        .read(localStorageServiceProvider)
        .setBool(LocalStorageKeys.hasSeenOnboarding, true);
    ref.invalidate(hasSeenOnboardingProvider);
  }
}

final onboardingViewModelProvider = NotifierProvider<OnboardingViewModel, void>(
  OnboardingViewModel.new,
);
