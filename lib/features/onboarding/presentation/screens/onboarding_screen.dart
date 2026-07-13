import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../view_model/onboarding_view_model.dart';

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}

const List<_OnboardingPageData> _pages = [
  _OnboardingPageData(
    icon: Icons.location_on_rounded,
    title: 'Request pickup,\nright where you are',
    description:
    'Drop a pin, pick your waste type, and get matched with the nearest available collector in real time.',
    gradient: [AppColors.primary, AppColors.primaryDark],
  ),
  _OnboardingPageData(
    icon: Icons.local_shipping_rounded,
    title: 'Track your collector\nlive',
    description:
    'Watch your collector move toward you on the map from acceptance to arrival — no more guessing when pickup happens.',
    gradient: [AppColors.primaryDark, AppColors.primaryDeeper],
  ),
  _OnboardingPageData(
    icon: Icons.eco_rounded,
    title: 'See your\nimpact',
    description:
    'Every completed pickup gives you a receipt with weight and an impact score, so you can see the difference you make.',
    gradient: [AppColors.accentDark, AppColors.primaryDeeper],
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  double _page = 0;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingViewModelProvider.notifier).complete();
    if (!mounted) return;
    AppRouter.pushAndRemoveUntil(RouteNames.roleGate);
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: AppSizes.durationSlow,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _index == _pages.length - 1;
    final current = _pages[_index];

    return Scaffold(
      backgroundColor: AppColors.primaryDeeper,
      body: Stack(
        children: [
          // Animated gradient backdrop that eases between each page's tone.
          AnimatedContainer(
            duration: AppSizes.durationSlow,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: current.gradient,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: AppColors.ambientGlow),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    child: AnimatedOpacity(
                      duration: AppSizes.durationFast,
                      opacity: isLastPage ? 0 : 1,
                      child: TextButton(
                        onPressed: isLastPage ? null : _finish,
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        child: const Text('Skip'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final delta = (_page - i);
                      return _OnboardingPage(data: _pages[i], parallax: delta);
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.paddingL,
                    AppSizes.spacing28,
                    AppSizes.paddingL,
                    AppSizes.spacing28,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppSizes.radius2XL),
                    ),
                    border: const Border(
                      top: BorderSide(color: Colors.white24, width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: AppSizes.durationMedium,
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(horizontal: AppSizes.spacing4),
                            width: active ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active ? Colors.white : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: AppSizes.spacing24),
                      SizedBox(
                        width: double.infinity,
                        height: AppSizes.buttonHeightL,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDeeper,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastPage ? 'Get started' : 'Continue',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(width: AppSizes.spacing8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final double parallax;
  const _OnboardingPage({required this.data, required this.parallax});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.translate(
            offset: Offset(parallax * -40, 0),
            child: Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.4),
              ),
              child: Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Icon(data.icon, size: 44, color: AppColors.primaryDeeper),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacing48),
          Transform.translate(
            offset: Offset(parallax * -20, 0),
            child: Text(
              data.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacing16),
          Transform.translate(
            offset: Offset(parallax * -10, 0),
            child: Text(
              data.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
      ),
    );
  }
}