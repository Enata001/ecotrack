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
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/rating_prompt_sheet.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/tap_scale.dart';

enum _HistoryFilter { all, active, completed, cancelled }

class RequestHistoryScreen extends ConsumerStatefulWidget {
  const RequestHistoryScreen({super.key});

  @override
  ConsumerState<RequestHistoryScreen> createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends ConsumerState<RequestHistoryScreen> {
  Stream<List<WasteRequest>>? _requestsStream;
  _HistoryFilter _filter = _HistoryFilter.all;

  Future<void> _openRatingSheet(WasteRequest request) async {
    await showRatingSheet(
      context: context,
      title: 'Rate your collector',
      subtitle: 'How was your pickup experience?',
      onSubmit: (stars, comment) async {
        final result = await ref.read(requestRepositoryProvider).submitRating(
          requestId: request.id,
          stars: stars,
          comment: comment,
        );
        return result.map(onSuccess: (_) => null, onError: (e) => e.message);
      },
    );
    // The stream this tile comes from re-emits once Firestore reflects
    // ratedByUser flipping to true — no manual refresh needed.
  }

  bool _matchesFilter(WasteRequest r) {
    switch (_filter) {
      case _HistoryFilter.all:
        return true;
      case _HistoryFilter.active:
        return r.status == RequestStatus.pending ||
            r.status == RequestStatus.accepted ||
            r.status == RequestStatus.enroute;
      case _HistoryFilter.completed:
        return r.status == RequestStatus.completed;
      case _HistoryFilter.cancelled:
        return r.status == RequestStatus.cancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    _requestsStream ??=
    uid == null ? null : ref.read(requestRepositoryProvider).watchUserRequests(uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Request history')),
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

                    final requests =
                    (snapshot.data ?? []).where(_matchesFilter).toList();
                    if (requests.isEmpty) {
                      return const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'Nothing here',
                        description: 'No requests match this filter yet.',
                      );
                    }

                    return ListView.separated(
                      itemCount: requests.length,
                      separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSizes.spacing10),
                      itemBuilder: (_, index) {
                        final request = requests[index];
                        final color = StatusPill.colorFor(request.status);
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
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.spacing12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request.address ??
                                            request.wasteTypes
                                                .map((e) => e.label)
                                                .join(', '),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (request.address != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          request.wasteTypes.map((e) => e.label).join(', '),
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: AppSizes.spacing4),
                                      Text(
                                        request.createdAt.timeAgo,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12.5,
                                        ),
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
                                        !request.ratedByUser) ...[
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