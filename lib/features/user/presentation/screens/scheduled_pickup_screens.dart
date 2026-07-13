import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/scheduled_pickup.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/tap_scale.dart';

/// Lists the user's scheduled/recurring pickups (created from New Request's
/// "Schedule" mode), and lets them edit or cancel one. Each schedule turns
/// into a real, trackable request automatically once its time arrives —
/// this screen only manages the template, not any request it's already
/// spawned.
class ScheduledPickupsScreen extends ConsumerStatefulWidget {
  const ScheduledPickupsScreen({super.key});

  @override
  ConsumerState<ScheduledPickupsScreen> createState() => _ScheduledPickupsScreenState();
}

class _ScheduledPickupsScreenState extends ConsumerState<ScheduledPickupsScreen> {
  Stream<List<ScheduledPickup>>? _schedulesStream;
  String? _cancellingId;

  Future<void> _confirmCancel(ScheduledPickup schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this schedule?'),
        content: Text(
          schedule.recurrence == PickupRecurrence.once
              ? 'This scheduled pickup will no longer be created.'
              : "This recurring pickup won't be created again. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel schedule'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancellingId = schedule.id);
    final result = await ref.read(requestRepositoryProvider).cancelSchedule(schedule.id);
    if (!mounted) return;
    setState(() => _cancellingId = null);

    result.map(
      onSuccess: (_) {},
      onError: (error) => context.showSnack(error.message, isError: true),
    );
  }

  Future<void> _editSchedule(ScheduledPickup schedule) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: _EditScheduleSheet(schedule: schedule),
      ),
    );
    // The stream re-emits automatically once Firestore reflects the edit —
    // no manual refresh needed here.
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    _schedulesStream ??=
    uid == null ? null : ref.read(requestRepositoryProvider).watchUserSchedules(uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Scheduled pickups')),
      body: SafeArea(
        child: uid == null || _schedulesStream == null
            ? const SizedBox.shrink()
            : StreamBuilder<List<ScheduledPickup>>(
          stream: _schedulesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(AppSizes.paddingM),
                child: Column(
                  children: [
                    ShimmerListTile(),
                    SizedBox(height: AppSizes.spacing8),
                    ShimmerListTile(),
                  ],
                ),
              );
            }

            final schedules = (snapshot.data ?? []).where((s) => s.active).toList()
              ..sort((a, b) => a.nextRunAt.compareTo(b.nextRunAt));

            if (schedules.isEmpty) {
              return const EmptyState(
                icon: Icons.calendar_month_rounded,
                title: 'No scheduled pickups',
                description:
                'Set one up from New Request by switching to "Schedule" instead of "Now".',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              itemCount: schedules.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spacing10),
              itemBuilder: (_, index) {
                final schedule = schedules[index];
                final cancelling = _cancellingId == schedule.id;
                return TapScale(
                  onTap: cancelling ? null : () => _editSchedule(schedule),
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.heroGradient,
                            borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: AppSizes.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule.address ?? schedule.wasteTypes.map((e) => e.label).join(', '),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (schedule.address != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  schedule.wasteTypes.map((e) => e.label).join(', '),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentSoft,
                                      borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
                                    ),
                                    child: Text(
                                      schedule.recurrence.label,
                                      style: const TextStyle(
                                        color: AppColors.accentDark,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Next: ${schedule.nextRunAt.formattedDate}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSizes.spacing4),
                        const Icon(Icons.edit_outlined, color: AppColors.grey300, size: 18),
                        const SizedBox(width: AppSizes.spacing8),
                        cancelling
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                          onPressed: () => _confirmCancel(schedule),
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
    );
  }
}

/// Edit form for an existing schedule. Location/address aren't editable
/// here (that would mean re-picking a map spot) — cancelling and creating
/// a new one is the path for moving a schedule somewhere else.
class _EditScheduleSheet extends ConsumerStatefulWidget {
  final ScheduledPickup schedule;
  const _EditScheduleSheet({required this.schedule});

  @override
  ConsumerState<_EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends ConsumerState<_EditScheduleSheet> {
  late Set<WasteType> _wasteTypes;
  late PickupRecurrence _recurrence;
  late DateTime _nextRunAt;
  late final TextEditingController _phoneController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _wasteTypes = widget.schedule.wasteTypes.toSet();
    _recurrence = widget.schedule.recurrence;
    _nextRunAt = widget.schedule.nextRunAt;
    _phoneController = TextEditingController(text: widget.schedule.contactPhone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextRunAt.isBefore(DateTime.now()) ? DateTime.now() : _nextRunAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextRunAt),
    );
    if (time == null) return;

    setState(() {
      _nextRunAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_wasteTypes.isEmpty) {
      setState(() => _error = 'Pick at least one waste type.');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'A phone number is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref.read(requestRepositoryProvider).updateSchedule(
      scheduleId: widget.schedule.id,
      wasteTypes: _wasteTypes.toList(),
      contactPhone: _phoneController.text.trim(),
      recurrence: _recurrence,
      nextRunAt: _nextRunAt,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    result.map(
      onSuccess: (_) => Navigator.of(context).pop(),
      onError: (error) => setState(() => _error = error.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.paddingL,
        AppSizes.spacing20,
        AppSizes.paddingL,
        AppSizes.paddingL + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSizes.spacing20),
              decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(2)),
            ),
            Text('Edit schedule', style: Theme.of(context).textTheme.headlineSmall),
            if (widget.schedule.address != null) ...[
              const SizedBox(height: AppSizes.spacing4),
              Text(
                widget.schedule.address!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSizes.spacing20),
            Text(
              'Waste type',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSizes.spacing8),
            Wrap(
              spacing: AppSizes.spacing8,
              runSpacing: AppSizes.spacing8,
              children: WasteType.values.map((type) {
                final selected = _wasteTypes.contains(type);
                return FilterChip(
                  label: Text(type.label),
                  selected: selected,
                  onSelected: (isSelected) => setState(() {
                    if (isSelected) {
                      _wasteTypes.add(type);
                    } else {
                      _wasteTypes.remove(type);
                    }
                    _error = null;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              'Contact phone number',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSizes.spacing8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                hintText: 'e.g. 024 123 4567',
                prefixIcon: Icon(Icons.call_outlined, size: 20),
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              'When',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSizes.spacing8),
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(_formatDateTime(_nextRunAt)),
            ),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              'Repeat',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSizes.spacing8),
            Wrap(
              spacing: AppSizes.spacing8,
              runSpacing: AppSizes.spacing8,
              children: PickupRecurrence.values.map((r) {
                return ChoiceChip(
                  label: Text(r.label),
                  selected: _recurrence == r,
                  onSelected: (_) => setState(() => _recurrence = r),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.spacing12),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: AppSizes.spacing24),
            CustomButton(
              text: 'Save changes',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour < 12 ? 'AM' : 'PM';
  return '${dateTime.day} ${months[dateTime.month - 1]}, $hour:$minute $period';
}