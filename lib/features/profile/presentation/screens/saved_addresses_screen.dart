import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/saved_address.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/shimmer_box.dart';

/// Lets a user review and remove the pickup addresses they've bookmarked
/// from New Request. Removing an address here only affects the saved
/// shortcut — it never touches any existing request.
class SavedAddressesScreen extends ConsumerStatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  ConsumerState<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen> {
  bool _loading = true;
  List<_Entry> _entries = [];
  String? _removingRaw;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    final user = await ref.read(authRepositoryProvider).fetchAppUser(uid);
    if (!mounted) return;
    setState(() {
      _entries = (user?.savedAddresses ?? [])
          .map((raw) {
        final parsed = SavedAddress.tryParse(raw);
        return parsed == null ? null : _Entry(raw: raw, address: parsed);
      })
          .whereType<_Entry>()
          .toList();
      _loading = false;
    });
  }

  Future<void> _remove(_Entry entry) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    setState(() => _removingRaw = entry.raw);
    final result = await ref
        .read(authRepositoryProvider)
        .removeSavedAddress(uid: uid, rawEntry: entry.raw);
    if (!mounted) return;
    setState(() => _removingRaw = null);

    result.map(
      onSuccess: (_) => setState(() => _entries.remove(entry)),
      onError: (error) => context.showSnack(error.message, isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Saved addresses')),
      body: SafeArea(
        child: _loading
            ? const Padding(
          padding: EdgeInsets.all(AppSizes.paddingM),
          child: Column(
            children: [
              ShimmerListTile(),
              SizedBox(height: AppSizes.spacing8),
              ShimmerListTile(),
            ],
          ),
        )
            : _entries.isEmpty
            ? const EmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'No saved addresses',
          description:
          'Tap the bookmark icon next to an address in New Request to save it here for next time.',
        )
            : ListView.separated(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          itemCount: _entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spacing10),
          itemBuilder: (_, index) {
            final entry = _entries[index];
            final removing = _removingRaw == entry.raw;
            return Container(
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
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bookmark_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  Expanded(
                    child: Text(
                      entry.address.label,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  removing
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    onPressed: () => _remove(entry),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Entry {
  final String raw;
  final SavedAddress address;
  const _Entry({required this.raw, required this.address});
}