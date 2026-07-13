import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/waste_request.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_args.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/rating_prompt_sheet.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/tap_scale.dart';

enum _HistoryFilter { all, active, completed, cancelled }

/// Collector-side counterpart to the user's request history: every job
/// this collector has ever been assigned, regardless of current status.
class CollectorHistoryScreen extends ConsumerStatefulWidget {
  const CollectorHistoryScreen({super.key});

  @override
  ConsumerState<CollectorHistoryScreen> createState() => _CollectorHistoryScreenState();
}

class _CollectorHistoryScreenState extends ConsumerState<CollectorHistoryScreen> {
  Stream<List<WasteRequest>>? _requestsStream;
  _HistoryFilter _filter = _HistoryFilter.all;

  bool _matchesFilter(WasteRequest r) {
    switch (_filter) {
      case _HistoryFilter.all:
        return true;
      case _HistoryFilter.active:
        return r.status == RequestStatus.accepted || r.status == RequestStatus.enroute;
      case _HistoryFilter.completed:
        return r.status == RequestStatus.completed;
      case _HistoryFilter.cancelled:
        return r.status == RequestStatus.cancelled;
    }
  }

  void _openJob(WasteRequest request) {
    switch (request.status) {
      case RequestStatus.completed:
        AppRouter.push(RouteNames.receipt, arguments: ReceiptArgs(requestId: request.id));
        break;
      case RequestStatus.accepted:
      case RequestStatus.enroute:
        AppRouter.push(RouteNames.activeRoute);
        break;
      case RequestStatus.pending:
      case RequestStatus.cancelled:
        _showDetailsSheet(request);
        break;
    }
  }

  Future<void> _openRatingSheet(WasteRequest request) async {
    await showRatingSheet(
      context: context,
      title: 'Rate this customer',
      subtitle: 'How did this pickup go?',
      onSubmit: (stars, comment) async {
        final result = await ref.read(requestRepositoryProvider).submitRating(
          requestId: request.id,
          stars: stars,
          comment: comment,
        );
        return result.map(onSuccess: (_) => null, onError: (e) => e.message);
      },
    );
  }

  void _showDetailsSheet(WasteRequest request) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.paddingL,
          AppSizes.spacing20,
          AppSizes.paddingL,
          AppSizes.paddingL + MediaQuery.of(sheetContext).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Job details', style: Theme.of(sheetContext).textTheme.headlineSmall),
                ),
                StatusPill(status: request.status),
              ],
            ),
            const SizedBox(height: AppSizes.spacing20),
            _DetailRow(
              label: 'Location',
              value: request.address ??
                  '${request.location.latitude.toStringAsFixed(5)}, '
                      '${request.location.longitude.toStringAsFixed(5)}',
            ),
            const SizedBox(height: AppSizes.spacing12),
            _DetailRow(label: 'Waste type', value: request.wasteTypes.map((e) => e.label).join(', ')),
            const SizedBox(height: AppSizes.spacing12),
            _DetailRow(label: 'Requested', value: request.createdAt.timeAgo),
            const SizedBox(height: AppSizes.spacing16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Helpers.openMapsNavigation(request.location),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('View on map'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    _requestsStream ??=
    uid == null ? null : ref.read(requestRepositoryProvider).watchCollectorRequests(uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Job history')),
      body: SafeArea(
        child: uid == null || _requestsStream == null
            ? const SizedBox.shrink()
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.paddingM,
                AppSizes.spacing8,
                AppSizes.paddingM,
                AppSizes.spacing8,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _HistoryFilter.values.map((f) {
                    final selected = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSizes.spacing8),
                      child: ChoiceChip(
                        label: Text(_labelFor(f)),
                        selected: selected,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.paddingM,
                  0,
                  AppSizes.paddingM,
                  AppSizes.paddingM,
                ),
                child: StreamBuilder<List<WasteRequest>>(
                  stream: _requestsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.builder(
                        itemCount: 6,
                        itemBuilder: (_, _) => const ShimmerListTile(),
                      );
                    }

                    final requests = (snapshot.data ?? []).where(_matchesFilter).toList();
                    if (requests.isEmpty) {
                      return const EmptyState(
                        icon: Icons.work_history_rounded,
                        title: 'No jobs here yet',
                        description: 'Completed and past pickups you handle will show up here.',
                      );
                    }

                    return ListView.separated(
                      itemCount: requests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spacing10),
                      itemBuilder: (_, index) {
                        final request = requests[index];
                        final color = StatusPill.colorFor(request.status);
                        return TapScale(
                          onTap: () => _openJob(request),
                          child: Container(
                            padding: const EdgeInsets.all(AppSizes.paddingM),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppSizes.radiusL),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.grey900.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.06)],
                                    ),
                                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                                  ),
                                  child: Icon(Icons.delete_outline_rounded, color: color, size: 20),
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
                                      Text(
                                        request.createdAt.timeAgo,
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusPill(status: request.status, dense: true),
                                    if (request.status == RequestStatus.completed &&
                                        !request.ratedByCollector) ...[
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () => _openRatingSheet(request),
                                        child: const Text(
                                          'Rate',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
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
          ],
        ),
      ),
    );
  }

  String _labelFor(_HistoryFilter f) {
    switch (f) {
      case _HistoryFilter.all:
        return 'All';
      case _HistoryFilter.active:
        return 'Active';
      case _HistoryFilter.completed:
        return 'Completed';
      case _HistoryFilter.cancelled:
        return 'Cancelled';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Flexible(
          child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}