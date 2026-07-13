import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/geo_point_data.dart';
import '../../../../core/models/waste_request.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_args.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../view_model/active_route_view_model.dart';

class ActiveRouteScreen extends ConsumerStatefulWidget {
  const ActiveRouteScreen({super.key});

  @override
  ConsumerState<ActiveRouteScreen> createState() => _ActiveRouteScreenState();
}

class _ActiveRouteScreenState extends ConsumerState<ActiveRouteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
      if (uid != null) {
        ref.read(activeRouteViewModelProvider.notifier).loadStops(uid);
      }
    });
  }

  Future<void> _optimize() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      await ref.read(activeRouteViewModelProvider.notifier).optimize(
        GeoPointData(latitude: position.latitude, longitude: position.longitude),
      );

      if (!mounted) return;
      final error = ref.read(activeRouteViewModelProvider).error;
      if (error != null) {
        context.showSnack(
          "Couldn't optimize route, showing default order",
          isError: false,
        );
      }
    } catch (_) {
      if (mounted) {
        context.showSnack("Couldn't optimize route, showing default order");
      }
    }
  }

  Future<void> _startTrip(WasteRequest stop) async {
    final success =
    await ref.read(activeRouteViewModelProvider.notifier).startEnroute(stop.id);
    if (!mounted) return;
    if (!success) {
      final error = ref.read(activeRouteViewModelProvider).error;
      context.showSnack(error ?? 'Could not start the trip.', isError: true);
    }
  }

  Future<void> _markArrived(WasteRequest stop) async {
    final success =
    await ref.read(activeRouteViewModelProvider.notifier).markArrived(stop.id);
    if (!mounted) return;
    if (success) {
      Helpers.showToast(message: 'User notified that you have arrived');
    } else {
      final error = ref.read(activeRouteViewModelProvider).error;
      context.showSnack(error ?? 'Could not mark arrival.', isError: true);
    }
  }

  Future<void> _completePickup(WasteRequest stop) async {
    await AppRouter.push(
      RouteNames.completePickup,
      arguments: CompletePickupArgs(requestId: stop.id),
    );
    if (!mounted) return;
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid != null) {
      ref.read(activeRouteViewModelProvider.notifier).loadStops(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeRouteViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Active route'),
        actions: [
          TextButton.icon(
            onPressed: state.optimizing ? null : _optimize,
            icon: state.optimizing
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.alt_route_rounded, size: 18),
            label: const Text('Optimize'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: state.loading
              ? ListView.builder(
            itemCount: 4,
            itemBuilder: (_, _) => const ShimmerListTile(),
          )
              : state.stops.isEmpty
              ? const EmptyState(
            icon: Icons.route_rounded,
            title: 'No active stops',
            description: 'Accept a request from Incoming Requests to build your route.',
          )
              : ListView.separated(
            itemCount: state.stops.length,
            separatorBuilder: (_, _) =>
            const SizedBox(height: AppSizes.spacing12),
            itemBuilder: (_, index) {
              final stop = state.stops[index];
              final eta = state.etaMinutes[stop.id];
              return _StopCard(
                index: index,
                stop: stop,
                eta: eta,
                onStartTrip: () => _startTrip(stop),
                onNavigate: () => Helpers.openMapsNavigation(stop.location),
                onMarkArrived: () => _markArrived(stop),
                onCall: stop.contactPhone != null
                    ? () => Helpers.callPhone(stop.contactPhone!)
                    : null,
                onComplete: () => _completePickup(stop),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final int index;
  final WasteRequest stop;
  final int? eta;
  final VoidCallback onStartTrip;
  final VoidCallback onNavigate;
  final VoidCallback onMarkArrived;
  final VoidCallback? onCall;
  final VoidCallback onComplete;

  const _StopCard({
    required this.index,
    required this.stop,
    required this.eta,
    required this.onStartTrip,
    required this.onNavigate,
    required this.onMarkArrived,
    required this.onCall,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isEnroute = stop.status == RequestStatus.enroute;
    final hasArrived = stop.arrivedAt != null;

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: isEnroute ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.grey900.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.address ?? stop.wasteTypes.map((e) => e.label).join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (stop.address != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        stop.wasteTypes.map((e) => e.label).join(', '),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (eta != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
                            ),
                            child: Text(
                              '$eta min',
                              style: const TextStyle(color: AppColors.accentDark, fontSize: 10.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            hasArrived ? 'Arrived' : (isEnroute ? 'En route' : 'Accepted'),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          if (!isEnroute)
            CustomButton(
              text: 'Start trip',
              icon: Icons.navigation_rounded,
              height: AppSizes.buttonHeightS,
              onPressed: onStartTrip,
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onNavigate,
                        icon: const Icon(Icons.directions_outlined, size: 16),
                        label: const Text('Navigate'),
                      ),
                    ),
                    if (onCall != null) ...[
                      const SizedBox(width: AppSizes.spacing8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCall,
                          icon: const Icon(Icons.call_outlined, size: 16),
                          label: const Text('Call'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.spacing8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasArrived ? null : onMarkArrived,
                        icon: Icon(
                          hasArrived ? Icons.check_circle_rounded : Icons.pin_drop_outlined,
                          size: 16,
                        ),
                        label: Text(hasArrived ? "Arrived" : "I've arrived"),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing8),
                    Expanded(
                      child: CustomButton(
                        text: 'Complete',
                        height: AppSizes.buttonHeightS,
                        onPressed: onComplete,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}