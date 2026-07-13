import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/models/geo_point_data.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../shared/app_logo.dart';
import '../../../../shared/widgets/tap_scale.dart';

class CollectorHomeScreen extends ConsumerStatefulWidget {
  const CollectorHomeScreen({super.key});

  @override
  ConsumerState<CollectorHomeScreen> createState() => _CollectorHomeScreenState();
}

class _CollectorHomeScreenState extends ConsumerState<CollectorHomeScreen> {
  bool _updating = false;
  bool _sharingLocation = false;
  bool? _lastKnownAvailable;
  StreamSubscription<Position>? _positionSubscription;
  late final Stream<bool> _availabilityStream;
  late final Stream<List<String>> _activeIdsStream;
  Future<AppUser?>? _userFuture;

  @override
  void initState() {
    super.initState();
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    _availabilityStream = uid == null
        ? const Stream.empty()
        : ref.read(collectorRepositoryProvider).watchIsAvailable(uid);
    _activeIdsStream = uid == null
        ? const Stream.empty()
        : ref.read(collectorRepositoryProvider).watchActiveRequestIds(uid);
    _userFuture = uid == null ? null : ref.read(authRepositoryProvider).fetchAppUser(uid);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _startSharingLocation() {
    if (_sharingLocation) return;
    _sharingLocation = true;
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen((position) {
      final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
      if (uid == null) return;
      ref.read(collectorRepositoryProvider).updateLocation(
        collectorId: uid,
        location: GeoPointData(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    });
  }

  void _stopSharingLocation() {
    _sharingLocation = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }


  void _syncLocationSharing(bool isAvailable) {
    if (_lastKnownAvailable == isAvailable) return;
    _lastKnownAvailable = isAvailable;
    isAvailable ? _startSharingLocation() : _stopSharingLocation();
  }

  Future<void> _toggleAvailability(bool value) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    setState(() => _updating = true);
    final result = await ref
        .read(collectorRepositoryProvider)
        .setAvailability(collectorId: uid, isAvailable: value);

    if (!mounted) return;
    setState(() => _updating = false);

    result.map(
      onSuccess: (_) {}, // the availability StreamBuilder picks up the change
      onError: (error) => context.showSnack(error.message, isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          children: [
            Row(
              children: [
                const AppLogo(size: 32),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greeting,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        'Collector dashboard',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                    ],
                  ),
                ),
                TapScale(
                  onTap: () => AppRouter.push(RouteNames.profile),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.grey50, shape: BoxShape.circle),
                    child: const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacing24),
            StreamBuilder<bool>(
              stream: _availabilityStream,
              builder: (context, snapshot) {
                final isAvailable = snapshot.data ?? false;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _syncLocationSharing(isAvailable);
                });

                return _AvailabilityCard(
                  isAvailable: isAvailable,
                  updating: _updating,
                  onChanged: _toggleAvailability,
                );
              },
            ),
            const SizedBox(height: AppSizes.spacing16),
            StreamBuilder<List<String>>(
              stream: _activeIdsStream,
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Row(
                  children: [
                    Expanded(
                      child: _StatChip(icon: Icons.inbox_outlined, label: 'Active stops', value: '$count'),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    Expanded(
                      child: FutureBuilder<AppUser?>(
                        future: _userFuture,
                        builder: (context, snapshot) {
                          final rating = snapshot.data?.rating;
                          return _StatChip(
                            icon: Icons.star_outline_rounded,
                            label: 'Rating',
                            value: rating == null ? '…' : rating.toStringAsFixed(1),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSizes.spacing28),
            const Text('Quick actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.2)),
            const SizedBox(height: AppSizes.spacing12),
            StreamBuilder<List<String>>(
              stream: _activeIdsStream,
              builder: (context, snapshot) {
                return _ActionCard(
                  icon: Icons.inbox_rounded,
                  title: 'Incoming requests',
                  subtitle: 'View and accept nearby pickups',
                  color: AppColors.primary,
                  onTap: () => AppRouter.push(RouteNames.incomingRequests),
                );
              },
            ),
            const SizedBox(height: AppSizes.spacing12),
            StreamBuilder<List<String>>(
              stream: _activeIdsStream,
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return _ActionCard(
                  icon: Icons.route_rounded,
                  title: 'Active route',
                  subtitle: 'Optimize stops and complete pickups',
                  color: AppColors.accentDark,
                  badgeCount: count,
                  onTap: () => AppRouter.push(RouteNames.activeRoute),
                );
              },
            ),
            const SizedBox(height: AppSizes.spacing12),
            _ActionCard(
              icon: Icons.work_history_rounded,
              title: 'Job history',
              subtitle: "Everything you've picked up or been assigned",
              color: AppColors.info,
              onTap: () => AppRouter.push(RouteNames.collectorHistory),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final bool isAvailable;
  final bool updating;
  final ValueChanged<bool> onChanged;

  const _AvailabilityCard({
    required this.isAvailable,
    required this.updating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppSizes.durationMedium,
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        gradient: isAvailable ? AppColors.heroGradient : null,
        color: isAvailable ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: Border.all(color: isAvailable ? Colors.transparent : AppColors.border),
        boxShadow: isAvailable
            ? [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 10)),
        ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isAvailable ? Colors.white.withValues(alpha: 0.18) : AppColors.grey50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAvailable ? Icons.bolt_rounded : Icons.bolt_outlined,
              color: isAvailable ? Colors.white : AppColors.grey500,
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAvailable ? "You're online" : "You're offline",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isAvailable ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAvailable
                      ? 'Visible to nearby pickup requests'
                      : 'Turn on to start receiving requests',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isAvailable
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          updating
              ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isAvailable ? Colors.white : AppColors.primary,
            ),
          )
              : Switch(
            value: isAvailable,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.grey900.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: AppSizes.spacing8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: AppColors.grey900.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.06)]),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: AppSizes.spacing4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (badgeCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppSizes.radiusCircular)),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSizes.spacing8),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey300),
          ],
        ),
      ),
    );
  }
}