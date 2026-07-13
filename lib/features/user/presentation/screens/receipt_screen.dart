import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/receipt.dart';
import '../../../../core/models/waste_request.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/rating_prompt_sheet.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/star_rating.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  final String requestId;
  const ReceiptScreen({super.key, required this.requestId});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  late final Future<Receipt?> _receiptFuture;
  late final Stream<WasteRequest?> _requestStream;

  @override
  void initState() {
    super.initState();
    _receiptFuture =
        ref.read(requestRepositoryProvider).fetchReceiptForRequest(widget.requestId);
    // A stream (not a one-off fetch) so the "rated" state flips the moment
    // the submitRating Cloud Function commits, without needing to manually
    // patch local state or re-navigate.
    _requestStream = ref.read(requestRepositoryProvider).watchRequest(widget.requestId);
  }

  void _copySummary(Receipt receipt) {
    Clipboard.setData(
      ClipboardData(
        text: 'I just recycled ${receipt.weightKg.toStringAsFixed(1)}kg of '
            '${receipt.wasteType} waste with an impact score of '
            '${receipt.impactScore.toStringAsFixed(2)} on EcoTrack ♻️',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _openRatingSheet(WasteRequest request, bool raterIsUser) async {
    await showRatingSheet(
      context: context,
      title: raterIsUser ? 'Rate your collector' : 'Rate this customer',
      subtitle: raterIsUser
          ? 'How was your pickup experience?'
          : 'How did this pickup go?',
      onSubmit: (stars, comment) async {
        final result = await ref.read(requestRepositoryProvider).submitRating(
          requestId: request.id,
          stars: stars,
          comment: comment,
        );
        return result.map(onSuccess: (_) => null, onError: (e) => e.message);
      },
    );
    // No manual state update needed — _requestStream picks up ratedByUser/
    // ratedByCollector flipping to true as soon as Firestore reflects it.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Receipt')),
      body: SafeArea(
        child: FutureBuilder<Receipt?>(
          future: _receiptFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  children: [
                    ShimmerBox(height: 96, width: 96, borderRadius: 48),
                    SizedBox(height: AppSizes.spacing24),
                    ShimmerBox(height: 20, width: 160),
                    SizedBox(height: AppSizes.spacing32),
                    ShimmerBox(height: 200, borderRadius: AppSizes.radiusL),
                  ],
                ),
              );
            }

            final receipt = snapshot.data;
            if (receipt == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingL),
                  child: Text(
                    'Receipt is still being generated. Check back shortly.',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.paddingL,
                AppSizes.paddingXL,
                AppSizes.paddingL,
                AppSizes.paddingL,
              ),
              children: [
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.4, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [AppColors.success.withValues(alpha: 0.22), AppColors.success.withValues(alpha: 0.0)],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.success.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 34),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing24),
                Text(
                  'Pickup complete',
                  textAlign: TextAlign.center,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                Text(
                  receipt.timestamp.formattedDate,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.spacing32),

                // Impact score is the emotional payoff of the whole flow —
                // given its own moment rather than buried in a row.
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSizes.spacing28,
                    horizontal: AppSizes.paddingL,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.eco_rounded, color: Colors.white.withValues(alpha: 0.7), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'IMPACT SCORE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: AppSizes.fontXS,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.spacing8),
                      Text(
                        receipt.impactScore.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spacing20),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(color: AppColors.grey900.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingM,
                    vertical: AppSizes.spacing4,
                  ),
                  child: Column(
                    children: [
                      _ReceiptRow(
                        icon: Icons.delete_outline_rounded,
                        label: 'Waste type',
                        value: receipt.wasteType.capitalize,
                      ),
                      const Divider(height: AppSizes.spacing24),
                      _ReceiptRow(
                        icon: Icons.scale_outlined,
                        label: 'Weight collected',
                        value: '${receipt.weightKg.toStringAsFixed(1)} kg',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spacing20),
                StreamBuilder<WasteRequest?>(
                  stream: _requestStream,
                  builder: (context, requestSnapshot) {
                    final request = requestSnapshot.data;
                    if (request == null) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.spacing20),
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
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                              child: const Icon(Icons.place_outlined, size: 17, color: AppColors.primary),
                            ),
                            const SizedBox(width: AppSizes.spacing12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pickup location',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    request.address ??
                                        '${request.location.latitude.toStringAsFixed(5)}, '
                                            '${request.location.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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
                    );
                  },
                ),
                StreamBuilder<WasteRequest?>(
                  stream: _requestStream,
                  builder: (context, requestSnapshot) {
                    final request = requestSnapshot.data;
                    final currentUid = ref.read(firebaseAuthProvider).currentUser?.uid;
                    if (request == null || currentUid == null) return const SizedBox.shrink();

                    final raterIsUser = request.userId == currentUid;
                    final raterIsCollector = request.collectorId == currentUid;
                    if (!raterIsUser && !raterIsCollector) return const SizedBox.shrink();

                    final alreadyRated = raterIsUser ? request.ratedByUser : request.ratedByCollector;

                    return Column(
                      children: [
                        if (alreadyRated)
                          Container(
                            padding: const EdgeInsets.all(AppSizes.paddingM),
                            decoration: BoxDecoration(
                              color: AppColors.successSoft,
                              borderRadius: BorderRadius.circular(AppSizes.radiusL),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                                SizedBox(width: AppSizes.spacing8),
                                Text(
                                  'Thanks for rating this pickup',
                                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSizes.paddingM),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppSizes.radiusL),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  raterIsUser ? 'How was your collector?' : 'How was this pickup?',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                ),
                                const SizedBox(height: AppSizes.spacing12),
                                StarRating(
                                  value: 0,
                                  size: 26,
                                  onChanged: (_) => _openRatingSheet(request, raterIsUser),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSizes.spacing20),
                      ],
                    );
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () => _copySummary(receipt),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share your impact'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ReceiptRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSizes.spacing8),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }
}