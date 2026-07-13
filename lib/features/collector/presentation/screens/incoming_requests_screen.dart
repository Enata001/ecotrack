import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/geo_point_data.dart';
import '../../../../core/models/waste_request.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/tap_scale.dart';
import '../../view_model/incoming_requests_view_model.dart';

class IncomingRequestsScreen extends ConsumerStatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  ConsumerState<IncomingRequestsScreen> createState() =>
      _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends ConsumerState<IncomingRequestsScreen> {
  GeoPointData? _myLocation;
  bool _locating = true;
  late final Stream<List<WasteRequest>> _pendingStream;

  @override
  void initState() {
    super.initState();
    _pendingStream = ref.read(incomingRequestsViewModelProvider.notifier).watchPending();
    _loadMyLocation();
  }

  Future<void> _loadMyLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.deniedForever &&
          permission != LocationPermission.denied) {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _myLocation = GeoPointData(
              latitude: position.latitude,
              longitude: position.longitude,
            );
          });
        }
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<MapEntry<WasteRequest, double?>> _visibleSorted(List<WasteRequest> requests) {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    final notDeclined = requests
        .where((r) => uid == null || !r.declinedByCollectorIds.contains(uid))
        .toList();

    final withDistance = notDeclined.map((r) {
      final distance =
      _myLocation == null ? null : Helpers.distanceMeters(_myLocation!, r.location);
      return MapEntry(r, distance);
    }).toList();

    if (_myLocation == null) return withDistance;

    final nearby = withDistance
        .where((e) => e.value == null || e.value! <= Helpers.nearbyRadiusMeters)
        .toList();
    nearby.sort((a, b) => (a.value ?? 0).compareTo(b.value ?? 0));
    return nearby;
  }

  Future<void> _handleAction(Future<bool> Function() action, String successMessage) async {
    final success = await action();
    if (!mounted) return;
    if (success) {
      Helpers.showToast(message: successMessage);
    } else {
      final error = ref.read(incomingRequestsViewModelProvider).error;
      context.showSnack(error ?? 'Something went wrong', isError: true);
    }
  }

  void _showDetails(WasteRequest request, double? distance) {
    final viewModel = ref.read(incomingRequestsViewModelProvider.notifier);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.paddingL,
            AppSizes.spacing20,
            AppSizes.paddingL,
            AppSizes.paddingL + MediaQuery.of(sheetContext).padding.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    Expanded(
                      child: Text('Pickup request', style: Theme.of(sheetContext).textTheme.headlineSmall),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing20),
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: 'Location',
                  value: request.address ??
                      '${request.location.latitude.toStringAsFixed(5)}, '
                          '${request.location.longitude.toStringAsFixed(5)}',
                ),
                const SizedBox(height: AppSizes.spacing12),
                _DetailRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Waste type',
                  value: request.wasteTypes.map((e) => e.label).join(', '),
                ),
                const SizedBox(height: AppSizes.spacing12),
                _DetailRow(
                  icon: Icons.social_distance_outlined,
                  label: 'Distance',
                  value: distance != null ? Helpers.formatDistanceKm(distance) : 'Unknown',
                ),
                const SizedBox(height: AppSizes.spacing12),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: 'Requested',
                  value: request.createdAt.timeAgo,
                ),
                const SizedBox(height: AppSizes.spacing16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Helpers.openMapsNavigation(request.location),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('View on map'),
                  ),
                ),
                if (request.photoUrl != null) ...[
                  const SizedBox(height: AppSizes.spacing20),
                  Text(
                    'Photo of the waste',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    child: Image.network(
                      request.photoUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (request.contactPhone != null && request.contactPhone!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.spacing16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Helpers.callPhone(request.contactPhone!),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: Text('Call ${request.contactPhone}'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.spacing24),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Decline',
                        outlined: true,
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _handleAction(
                                () => viewModel.decline(request.id),
                            'Request declined',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    Expanded(
                      child: CustomButton(
                        text: 'Accept',
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _handleAction(
                                () => viewModel.accept(request.id),
                            'Request accepted',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incomingRequestsViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Incoming requests')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: StreamBuilder<List<WasteRequest>>(
            stream: _pendingStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || _locating) {
                return ListView.builder(
                  itemCount: 5,
                  itemBuilder: (_, _) => const ShimmerListTile(),
                );
              }

              final entries = _visibleSorted(snapshot.data ?? []);
              if (entries.isEmpty) {
                return const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'All caught up',
                  description: 'No pending requests nearby right now — new ones will show up here instantly.',
                );
              }

              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spacing10),
                itemBuilder: (_, index) {
                  final entry = entries[index];
                  final request = entry.key;
                  final distance = entry.value;
                  final isBusy =
                      state.accepting && state.acceptingRequestId == request.id;
                  final isNear = distance != null && distance <= 1000;

                  return TapScale(
                    onTap: () => _showDetails(request, distance),
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
                              gradient: LinearGradient(
                                colors: [AppColors.primary.withValues(alpha: 0.14), AppColors.primary.withValues(alpha: 0.05)],
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
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (request.address != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    request.wasteTypes.map((e) => e.label).join(', '),
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: AppSizes.spacing4),
                                Row(
                                  children: [
                                    if (isNear) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.successSoft,
                                          borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
                                        ),
                                        child: const Text(
                                          'Nearby',
                                          style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Flexible(
                                      child: Text(
                                        distance != null
                                            ? '${Helpers.formatDistanceKm(distance)} · ${request.createdAt.timeAgo}'
                                            : request.createdAt.timeAgo,
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSizes.spacing8),
                          SizedBox(
                            width: 92,
                            child: CustomButton(
                              text: 'Accept',
                              height: AppSizes.buttonHeightS,
                              loading: isBusy,
                              onPressed: () => _handleAction(
                                    () => ref
                                    .read(incomingRequestsViewModelProvider.notifier)
                                    .accept(request.id),
                                'Request accepted',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: AppColors.grey50, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: AppSizes.spacing12),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}