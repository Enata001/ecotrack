import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/models/waste_request.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_args.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../shared/app_logo.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/tap_scale.dart';

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  Stream<List<WasteRequest>>? _requestsStream;
  Future<AppUser?>? _userFuture;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _refresh() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _userFuture = ref.read(authRepositoryProvider).fetchAppUser(uid);
    });
    await _userFuture;
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    _requestsStream ??=
    uid == null ? null : ref.read(requestRepositoryProvider).watchUserRequests(uid);
    _userFuture ??= uid == null ? null : ref.read(authRepositoryProvider).fetchAppUser(uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: uid == null || _requestsStream == null
            ? const SizedBox.shrink()
            : RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: StreamBuilder<List<WasteRequest>>(
            stream: _requestsStream,
            builder: (context, snapshot) {
              final requests = snapshot.data ?? [];
              final loading = snapshot.connectionState == ConnectionState.waiting;
              final activeCount = requests
                  .where(
                    (r) =>
                r.status == RequestStatus.pending ||
                    r.status == RequestStatus.accepted ||
                    r.status == RequestStatus.enroute,
              )
                  .length;
              final completedCount =
                  requests.where((r) => r.status == RequestStatus.completed).length;
              final totalImpact = requests.length; // placeholder aggregate for stat row

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.paddingM,
                      AppSizes.spacing8,
                      AppSizes.paddingM,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HomeHeader(greeting: _greeting, userFuture: _userFuture),
                          const SizedBox(height: AppSizes.spacing20),
                          const _PickupHeroCard(),
                          const SizedBox(height: AppSizes.spacing20),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.local_shipping_outlined,
                                  label: 'Active',
                                  value: '$activeCount',
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: AppSizes.spacing12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.check_circle_outline_rounded,
                                  label: 'Completed',
                                  value: '$completedCount',
                                  color: AppColors.accentDark,
                                ),
                              ),
                              const SizedBox(width: AppSizes.spacing12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.eco_outlined,
                                  label: 'Total',
                                  value: '$totalImpact',
                                  color: AppColors.info,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.spacing28),
                          SectionHeader(
                            title: 'Recent requests',
                            actionLabel: requests.isEmpty ? null : 'See all',
                            onAction: () => AppRouter.push(RouteNames.requestHistory),
                          ),
                          const SizedBox(height: AppSizes.spacing8),
                        ],
                      ),
                    ),
                  ),
                  if (loading)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
                      sliver: SliverList.builder(
                        itemCount: 3,
                        itemBuilder: (_, _) => const Padding(
                          padding: EdgeInsets.only(bottom: AppSizes.spacing8),
                          child: ShimmerListTile(),
                        ),
                      ),
                    )
                  else if (requests.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.recycling_rounded,
                        title: 'No requests yet',
                        description: 'Your pickup requests will show up here once you make one.',
                        actionLabel: 'Request a pickup',
                        onAction: () => AppRouter.push(RouteNames.newRequest),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.paddingM,
                        0,
                        AppSizes.paddingM,
                        AppSizes.spacing32,
                      ),
                      sliver: SliverList.separated(
                        itemCount: requests.length > 5 ? 5 : requests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spacing10),
                        itemBuilder: (_, index) => _RequestTile(request: requests[index]),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final Future<AppUser?>? userFuture;
  const _HomeHeader({required this.greeting, required this.userFuture});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppLogo(size: 34),
        const SizedBox(width: AppSizes.spacing12),
        Expanded(
          child: FutureBuilder<AppUser?>(
            future: userFuture,
            builder: (context, snapshot) {
              final name = snapshot.data?.name.split(' ').first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    name == null ? 'Welcome back' : '$name 👋',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ),
        TapScale(
          onTap: () => AppRouter.push(RouteNames.requestHistory),
          child: _HeaderIconButton(icon: Icons.history_rounded),
        ),
        const SizedBox(width: AppSizes.spacing8),
        TapScale(
          onTap: () => AppRouter.push(RouteNames.profile),
          child: FutureBuilder<AppUser?>(
            future: userFuture,
            builder: (context, snapshot) {
              final photoUrl = snapshot.data?.photoUrl;
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.heroGradient,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipOval(
                  child: photoUrl == null || photoUrl.isEmpty
                      ? const Icon(Icons.person_rounded, color: Colors.white, size: 20)
                      : Image.network(photoUrl, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  const _HeaderIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(color: AppColors.grey50, shape: BoxShape.circle),
      child: Icon(icon, size: 19, color: AppColors.textPrimary),
    );
  }
}

class _PickupHeroCard extends StatelessWidget {
  const _PickupHeroCard();

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () => AppRouter.push(RouteNames.newRequest),
      child: Container(
        height: 230,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: AppSizes.blurMedium,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(child: _HomeMapPreview()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.primaryDeeper.withValues(alpha: 0.55),
                      AppColors.primaryDeeper.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppSizes.paddingM,
              left: AppSizes.paddingM,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'New pickup',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Positioned(
              left: AppSizes.paddingM,
              right: AppSizes.paddingM,
              bottom: AppSizes.paddingM,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Request a pickup',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Tap to set a location and get matched',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: AppColors.grey900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing16, horizontal: AppSizes.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.grey900.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: AppSizes.spacing12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, height: 1)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _HomeMapPreview extends StatefulWidget {
  const _HomeMapPreview();

  @override
  State<_HomeMapPreview> createState() => _HomeMapPreviewState();
}

class _HomeMapPreviewState extends State<_HomeMapPreview> {
  static const _fallbackCenter = LatLng(5.6037, -0.1870);

  LatLng? _center;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _center = LatLng(position.latitude, position.longitude));
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(_center!, 14));
    } catch (_) {
      // Fall back to the default center silently; this is a preview only.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _center ?? _fallbackCenter,
        zoom: 14,
      ),
      onMapCreated: (controller) => _controller = controller,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
    );
  }
}

class _RequestTile extends StatelessWidget {
  final WasteRequest request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () {
        if (request.status == RequestStatus.completed) {
          AppRouter.push(
            RouteNames.receipt,
            arguments: ReceiptArgs(requestId: request.id),
          );
        } else {
          AppRouter.push(
            RouteNames.requestTracking,
            arguments: RequestTrackingArgs(requestId: request.id),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: AppColors.grey900.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.address ?? request.wasteTypes.map((e) => e.label).join(', '),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.spacing4),
                  Text(
                    request.createdAt.timeAgo,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            StatusPill(status: request.status, dense: true),
          ],
        ),
      ),
    );
  }
}