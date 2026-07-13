import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../../shared/widgets/live_tracking_map.dart';
import '../../../../shared/widgets/shimmer_box.dart';

class RequestTrackingScreen extends ConsumerStatefulWidget {
  final String requestId;
  const RequestTrackingScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestTrackingScreen> createState() =>
      _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends ConsumerState<RequestTrackingScreen> {
  late final Stream<WasteRequest?> _requestStream;
  String? _subscribedCollectorId;
  Stream<GeoPointData?>? _collectorLocationStream;
  bool _navigatedToReceipt = false;
  bool _cancelling = false;
  bool _retrying = false;
  String? _collectorPhoneFetchedFor;
  String? _collectorPhone;

  @override
  void initState() {
    super.initState();
    _requestStream = ref.read(requestRepositoryProvider).watchRequest(widget.requestId);
  }

  void _maybeFetchCollectorPhone(String? collectorId) {
    if (collectorId == null || _collectorPhoneFetchedFor == collectorId) return;
    _collectorPhoneFetchedFor = collectorId;
    ref.read(authRepositoryProvider).fetchAppUser(collectorId).then((user) {
      if (!mounted) return;
      setState(() => _collectorPhone = user?.phone);
    });
  }

  /// Re-submits a cancelled request as a brand-new pending one, carrying
  /// over the same location, waste types, contact number, and photo (if
  /// any) so the person doesn't have to redo the whole form.
  Future<void> _retry(WasteRequest request) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? request.userId;
    setState(() => _retrying = true);

    final result = await ref.read(requestRepositoryProvider).createRequest(
      userId: uid,
      location: request.location,
      address: request.address,
      wasteTypes: request.wasteTypes,
      contactPhone: request.contactPhone ?? '',
      existingPhotoUrl: request.photoUrl,
    );

    if (!mounted) return;
    setState(() => _retrying = false);

    result.map(
      onSuccess: (newRequestId) {
        Helpers.showToast(message: 'New pickup request submitted');
        AppRouter.pushReplacement(
          RouteNames.requestTracking,
          arguments: RequestTrackingArgs(requestId: newRequestId),
        );
      },
      onError: (error) => context.showSnack(error.message, isError: true),
    );
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text('This will cancel the pickup request. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _cancelling = true);
    final result =
    await ref.read(requestRepositoryProvider).cancelRequest(widget.requestId);
    if (!mounted) return;
    setState(() => _cancelling = false);

    result.map(
      onSuccess: (_) {
        Helpers.showToast(message: 'Request cancelled');
        AppRouter.pop();
      },
      onError: (error) => context.showSnack(error.message, isError: true),
    );
  }

  String _statusLabel(WasteRequest request) {
    switch (request.status) {
      case RequestStatus.pending:
        return 'Waiting for a collector to accept';
      case RequestStatus.accepted:
        return 'Collector assigned — getting ready';
      case RequestStatus.enroute:
        return request.arrivedAt != null
            ? 'Your collector has arrived'
            : 'Collector is on the way';
      case RequestStatus.completed:
        return 'Pickup completed';
      case RequestStatus.cancelled:
        return 'Request cancelled';
    }
  }

  IconData _statusIcon(WasteRequest request) {
    switch (request.status) {
      case RequestStatus.pending:
        return Icons.hourglass_top_rounded;
      case RequestStatus.accepted:
        return Icons.task_alt_rounded;
      case RequestStatus.enroute:
        return request.arrivedAt != null ? Icons.pin_drop_rounded : Icons.local_shipping_rounded;
      case RequestStatus.completed:
        return Icons.check_circle_rounded;
      case RequestStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  Stream<GeoPointData?>? _locationStreamFor(String? collectorId) {
    if (collectorId == null) {
      _subscribedCollectorId = null;
      _collectorLocationStream = null;
      return null;
    }
   if (_subscribedCollectorId != collectorId) {
      _subscribedCollectorId = collectorId;
      _collectorLocationStream =
          ref.read(collectorRepositoryProvider).watchCollectorLocation(collectorId);
    }
    return _collectorLocationStream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Track pickup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: StreamBuilder<WasteRequest?>(
            stream: _requestStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _TrackingSkeleton();
              }

              final request = snapshot.data;
              if (request == null) {
                return Center(
                  child: Text('Request not found', style: context.textTheme.bodyMedium),
                );
              }

              if (request.status == RequestStatus.completed && !_navigatedToReceipt) {
                _navigatedToReceipt = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  AppRouter.pushReplacement(
                    RouteNames.receipt,
                    arguments: ReceiptArgs(requestId: widget.requestId),
                  );
                });
              }

              final locationStream = _locationStreamFor(request.collectorId);
              _maybeFetchCollectorPhone(request.collectorId);

              return ListView(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: AppColors.grey900.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: locationStream == null
                          ? LiveTrackingMap(
                        destination: request.location,
                        collectorLocation: null,
                      )
                          : StreamBuilder<GeoPointData?>(
                        stream: locationStream,
                        builder: (context, locSnapshot) {
                          return LiveTrackingMap(
                            destination: request.location,
                            collectorLocation: locSnapshot.data,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing12, vertical: AppSizes.spacing8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: AppSizes.spacing8),
                        Expanded(
                          child: Text(
                            request.address ??
                                '${request.location.latitude.toStringAsFixed(5)}, '
                                    '${request.location.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Helpers.openMapsNavigation(request.location),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing20),
                  if (request.status != RequestStatus.cancelled) ...[
                    _StatusTimeline(request: request),
                    const SizedBox(height: AppSizes.spacing20),
                  ],
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      gradient: request.status == RequestStatus.cancelled ? null : AppColors.heroGradient,
                      color: request.status == RequestStatus.cancelled ? AppColors.errorSoft : null,
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      boxShadow: request.status == RequestStatus.cancelled
                          ? null
                          : [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: request.status == RequestStatus.cancelled
                                ? AppColors.error.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _statusIcon(request),
                            color: request.status == RequestStatus.cancelled ? AppColors.error : Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSizes.spacing12),
                        Expanded(
                          child: Text(
                            _statusLabel(request),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: request.status == RequestStatus.cancelled ? AppColors.error : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_collectorPhone != null &&
                      _collectorPhone!.isNotEmpty &&
                      (request.status == RequestStatus.accepted ||
                          request.status == RequestStatus.enroute)) ...[
                    const SizedBox(height: AppSizes.spacing12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Helpers.callPhone(_collectorPhone!),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: const Text('Call collector'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.spacing20),
                  const Text('Waste types', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: AppSizes.spacing8),
                  Wrap(
                    spacing: AppSizes.spacing8,
                    children: request.wasteTypes
                        .map((t) => Chip(label: Text(t.label)))
                        .toList(),
                  ),
                  if (request.status == RequestStatus.pending ||
                      request.status == RequestStatus.accepted) ...[
                    const SizedBox(height: AppSizes.spacing24),
                    CustomButton.danger(
                      text: 'Cancel request',
                      loading: _cancelling,
                      onPressed: _confirmCancel,
                    ),
                  ],
                  if (request.status == RequestStatus.cancelled) ...[
                    const SizedBox(height: AppSizes.spacing24),
                    CustomButton(
                      text: 'Request again',
                      icon: Icons.replay_rounded,
                      loading: _retrying,
                      onPressed: () => _retry(request),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final WasteRequest request;
  const _StatusTimeline({required this.request});

  int get _stageIndex {
    switch (request.status) {
      case RequestStatus.pending:
        return 0;
      case RequestStatus.accepted:
        return 1;
      case RequestStatus.enroute:
        return request.arrivedAt != null ? 3 : 2;
      case RequestStatus.completed:
        return 4;
      case RequestStatus.cancelled:
        return 0;
    }
  }

  static const _labels = ['Requested', 'Accepted', 'En route', 'Arrived'];

  @override
  Widget build(BuildContext context) {
    final stage = _stageIndex;
    return Row(
      children: List.generate(_labels.length, (i) {
        final reached = i <= stage;
        final isLast = i == _labels.length - 1;
        return Expanded(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: AppSizes.durationMedium,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached ? AppColors.primary : AppColors.grey100,
                    ),
                    child: reached
                        ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: reached ? AppColors.primary : AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: AnimatedContainer(
                    duration: AppSizes.durationMedium,
                    margin: const EdgeInsets.only(bottom: 14),
                    height: 2,
                    color: i < stage ? AppColors.primary : AppColors.grey100,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _TrackingSkeleton extends StatelessWidget {
  const _TrackingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ShimmerBox(height: 260, borderRadius: AppSizes.radiusL),
        SizedBox(height: AppSizes.spacing24),
        ShimmerBox(height: 56, borderRadius: AppSizes.radiusM),
      ],
    );
  }
}