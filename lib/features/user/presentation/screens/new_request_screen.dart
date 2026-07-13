import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/geo_point_data.dart';
import '../../../../core/models/saved_address.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/enums.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../view_model/new_request_view_model.dart';

const _defaultCenter = LatLng(5.6037, -0.1870); // Accra, GH fallback center

class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  GoogleMapController? _mapController;
  final _searchController = TextEditingController();
  final _phoneController = TextEditingController();
  final _searchFocus = FocusNode();
  final _geocoding = Geocoding();

  bool _locating = false;
  bool _searching = false;
  String? _resolvedAddress;
  bool _resolvingAddress = false;
  List<SavedAddress> _savedAddresses = [];
  bool _savingAddress = false;

  @override
  void initState() {
    super.initState();
    _prefillPhone();
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    final user = await ref.read(authRepositoryProvider).fetchAppUser(uid);
    if (!mounted || user == null) return;
    setState(() {
      _savedAddresses = user.savedAddresses
          .map(SavedAddress.tryParse)
          .whereType<SavedAddress>()
          .toList();
    });
  }

  Future<void> _prefillPhone() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    final user = await ref.read(authRepositoryProvider).fetchAppUser(uid);
    if (!mounted || user?.phone == null || user!.phone!.isEmpty) return;
    _phoneController.text = user.phone!;
    ref.read(newRequestViewModelProvider.notifier).setPhone(user.phone!);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _phoneController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _setLocation(LatLng point, {bool moveCamera = true}) async {
    ref.read(newRequestViewModelProvider.notifier).setLocation(
      GeoPointData(latitude: point.latitude, longitude: point.longitude),
    );
    if (moveCamera) {
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
    }
    _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _resolvingAddress = true;
      _resolvedAddress = null;
    });
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (!mounted || placemarks.isEmpty) return;
      final p = placemarks.first;
      final parts = [p.street, p.subLocality, p.locality]
          .where((s) => s != null && s.isNotEmpty)
          .toList();
      setState(() => _resolvedAddress = parts.isEmpty ? null : parts.join(', '));
    } catch (_) {
      // Reverse geocoding is a display nicety — fall back to coordinates.
    } finally {
      if (mounted) setState(() => _resolvingAddress = false);
    }
  }

  /// Jumps straight to a previously-saved address. We already have its
  /// label, so there's no need to wait on a reverse-geocode round trip.
  Future<void> _selectSavedAddress(SavedAddress address) async {
    final point = LatLng(address.latitude, address.longitude);
    ref.read(newRequestViewModelProvider.notifier).setLocation(
      GeoPointData(latitude: address.latitude, longitude: address.longitude),
    );
    setState(() {
      _resolvedAddress = address.label;
      _resolvingAddress = false;
    });
    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
  }

  bool get _currentLocationIsSaved {
    final state = ref.read(newRequestViewModelProvider);
    final location = state.location;
    if (location == null) return false;
    return _savedAddresses.any((a) => a.isNear(location.latitude, location.longitude));
  }

  Future<void> _saveCurrentAddress() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    final location = ref.read(newRequestViewModelProvider).location;
    if (uid == null || location == null || _savingAddress) return;

    setState(() => _savingAddress = true);
    final address = SavedAddress(
      label: _resolvedAddress ??
          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
      latitude: location.latitude,
      longitude: location.longitude,
    );

    final result = await ref.read(authRepositoryProvider).addSavedAddress(uid: uid, address: address);
    if (!mounted) return;
    setState(() => _savingAddress = false);

    result.map(
      onSuccess: (_) {
        setState(() => _savedAddresses = [..._savedAddresses, address]);
        Helpers.showToast(message: 'Address saved');
      },
      onError: (error) => context.showSnack(error.message, isError: true),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          context.showSnack(
            'Location permission permanently denied. Enable it in settings.',
            isError: true,
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      await _setLocation(LatLng(position.latitude, position.longitude));
    } catch (e) {
      if (mounted) context.showSnack('Could not get location.', isError: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final results = await _geocoding.locationFromAddress(query);
      if (!mounted) return;
      if (results.isEmpty) {
        context.showSnack('No results for "$query"', isError: true);
        return;
      }
      final first = results.first;
      await _setLocation(LatLng(first.latitude, first.longitude));
    } catch (_) {
      if (mounted) {
        context.showSnack('Could not find that address.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;

    ref.read(newRequestViewModelProvider.notifier).setPhoto(File(picked.path));
  }

  Future<void> _submit() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    final notifier = ref.read(newRequestViewModelProvider.notifier);
    final isScheduled = ref.read(newRequestViewModelProvider).isScheduled;
    final success = isScheduled
        ? await notifier.submitSchedule(uid, address: _resolvedAddress)
        : await notifier.submit(uid, address: _resolvedAddress);
    if (!mounted) return;

    if (success) {
      Helpers.showToast(
        message: isScheduled ? 'Pickup scheduled' : 'Pickup request submitted',
      );
      AppRouter.pop();
    } else {
      final error = ref.read(newRequestViewModelProvider).error;
      context.showSnack(error ?? 'Could not submit request', isError: true);
    }
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    ref.read(newRequestViewModelProvider.notifier).setScheduledFor(combined);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newRequestViewModelProvider);
    final selectedLatLng = state.location != null
        ? LatLng(state.location!.latitude, state.location!.longitude)
        : null;
    final sheetHeight = MediaQuery.of(context).size.height * 0.55;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _defaultCenter,
                zoom: 12,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: (point) => _setLocation(point, moveCamera: false),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              padding: EdgeInsets.only(bottom: sheetHeight),
              markers: {
                if (selectedLatLng != null)
                  Marker(
                    markerId: const MarkerId('selected'),
                    position: selectedLatLng,
                    draggable: true,
                    onDragEnd: (point) => _setLocation(point, moveCamera: false),
                  ),
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => AppRouter.pop(),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  Expanded(
                    child: _SearchBar(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      searching: _searching,
                      onSubmitted: (_) => _searchAddress(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: AppSizes.paddingM,
            bottom: sheetHeight + AppSizes.paddingM,
            child: _RoundIconButton(
              icon: Icons.my_location_rounded,
              loading: _locating,
              accent: true,
              onTap: _useCurrentLocation,
            ),
          ),
          _RequestBottomSheet(
            location: state.location,
            address: _resolvedAddress,
            resolvingAddress: _resolvingAddress,
            selectedWasteTypes: state.selectedWasteTypes,
            photo: state.photo,
            phoneController: _phoneController,
            submitting: state.submitting,
            sheetHeight: sheetHeight,
            savedAddresses: _savedAddresses,
            currentLocationIsSaved: _currentLocationIsSaved,
            savingAddress: _savingAddress,
            onSelectSavedAddress: _selectSavedAddress,
            onSaveAddress: _saveCurrentAddress,
            isScheduled: state.isScheduled,
            scheduledFor: state.scheduledFor,
            recurrence: state.recurrence,
            onScheduleModeChanged: (v) =>
                ref.read(newRequestViewModelProvider.notifier).setScheduleMode(v),
            onPickDateTime: _pickScheduleDateTime,
            onRecurrenceChanged: (r) =>
                ref.read(newRequestViewModelProvider.notifier).setRecurrence(r),
            onToggleWasteType: (type) => ref
                .read(newRequestViewModelProvider.notifier)
                .toggleWasteType(type),
            onPhoneChanged: (value) =>
                ref.read(newRequestViewModelProvider.notifier).setPhone(value),
            onPickPhoto: _pickPhoto,
            onRemovePhoto: () =>
                ref.read(newRequestViewModelProvider.notifier).setPhoto(null),
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final ValueChanged<String> onSubmitted;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
        boxShadow: [
          BoxShadow(
            color: AppColors.grey900.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.grey500, size: 20),
          const SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              decoration: const InputDecoration(
                hintText: 'Search for an address',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (searching)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  final bool accent;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.loading = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppColors.primary : AppColors.surface,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: AppColors.grey900.withValues(alpha: 0.25),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: loading
              ? Padding(
            padding: const EdgeInsets.all(13),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accent ? Colors.white : AppColors.primary,
            ),
          )
              : Icon(icon, color: accent ? Colors.white : AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _RequestBottomSheet extends StatelessWidget {
  final GeoPointData? location;
  final String? address;
  final bool resolvingAddress;
  final Set<WasteType> selectedWasteTypes;
  final File? photo;
  final TextEditingController phoneController;
  final bool submitting;
  final double sheetHeight;
  final List<SavedAddress> savedAddresses;
  final bool currentLocationIsSaved;
  final bool savingAddress;
  final ValueChanged<SavedAddress> onSelectSavedAddress;
  final VoidCallback onSaveAddress;
  final bool isScheduled;
  final DateTime? scheduledFor;
  final PickupRecurrence recurrence;
  final ValueChanged<bool> onScheduleModeChanged;
  final VoidCallback onPickDateTime;
  final ValueChanged<PickupRecurrence> onRecurrenceChanged;
  final ValueChanged<WasteType> onToggleWasteType;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onSubmit;

  const _RequestBottomSheet({
    required this.location,
    required this.address,
    required this.resolvingAddress,
    required this.selectedWasteTypes,
    required this.photo,
    required this.phoneController,
    required this.submitting,
    required this.sheetHeight,
    required this.savedAddresses,
    required this.currentLocationIsSaved,
    required this.savingAddress,
    required this.onSelectSavedAddress,
    required this.onSaveAddress,
    required this.isScheduled,
    required this.scheduledFor,
    required this.recurrence,
    required this.onScheduleModeChanged,
    required this.onPickDateTime,
    required this.onRecurrenceChanged,
    required this.onToggleWasteType,
    required this.onPhoneChanged,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        height: sheetHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSizes.radius2XL)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 28, offset: const Offset(0, -8)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: AnimatedSwitcher(
            duration: AppSizes.durationMedium,
            child: location == null
                ? _HintState(
              key: const ValueKey('hint'),
              savedAddresses: savedAddresses,
              onSelectSavedAddress: onSelectSavedAddress,
            )
                : _SelectedState(
              key: const ValueKey('selected'),
              address: address,
              resolvingAddress: resolvingAddress,
              location: location!,
              selectedWasteTypes: selectedWasteTypes,
              photo: photo,
              phoneController: phoneController,
              submitting: submitting,
              currentLocationIsSaved: currentLocationIsSaved,
              savingAddress: savingAddress,
              onSaveAddress: onSaveAddress,
              isScheduled: isScheduled,
              scheduledFor: scheduledFor,
              recurrence: recurrence,
              onScheduleModeChanged: onScheduleModeChanged,
              onPickDateTime: onPickDateTime,
              onRecurrenceChanged: onRecurrenceChanged,
              onToggleWasteType: onToggleWasteType,
              onPhoneChanged: onPhoneChanged,
              onPickPhoto: onPickPhoto,
              onRemovePhoto: onRemovePhoto,
              onSubmit: onSubmit,
            ),
          ),
        ),
      ),
    );
  }
}

class _HintState extends StatelessWidget {
  final List<SavedAddress> savedAddresses;
  final ValueChanged<SavedAddress> onSelectSavedAddress;

  const _HintState({
    super.key,
    required this.savedAddresses,
    required this.onSelectSavedAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: AppSizes.spacing24),
          decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: AppSizes.spacing16),
        Text('Where should we pick up?', style: context.textTheme.titleMedium),
        const SizedBox(height: AppSizes.spacing8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
          child: Text(
            'Search for an address above, tap the map, or use your current location.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        if (savedAddresses.isNotEmpty) ...[
          const SizedBox(height: AppSizes.spacing20),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
              itemCount: savedAddresses.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.spacing8),
              itemBuilder: (_, index) {
                final saved = savedAddresses[index];
                return ActionChip(
                  avatar: const Icon(Icons.bookmark_rounded, size: 15, color: AppColors.primary),
                  label: Text(saved.label, overflow: TextOverflow.ellipsis),
                  onPressed: () => onSelectSavedAddress(saved),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectedState extends StatelessWidget {
  final String? address;
  final bool resolvingAddress;
  final GeoPointData location;
  final Set<WasteType> selectedWasteTypes;
  final File? photo;
  final TextEditingController phoneController;
  final bool submitting;
  final bool currentLocationIsSaved;
  final bool savingAddress;
  final VoidCallback onSaveAddress;
  final bool isScheduled;
  final DateTime? scheduledFor;
  final PickupRecurrence recurrence;
  final ValueChanged<bool> onScheduleModeChanged;
  final VoidCallback onPickDateTime;
  final ValueChanged<PickupRecurrence> onRecurrenceChanged;
  final ValueChanged<WasteType> onToggleWasteType;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onSubmit;

  const _SelectedState({
    super.key,
    required this.address,
    required this.resolvingAddress,
    required this.location,
    required this.selectedWasteTypes,
    required this.photo,
    required this.phoneController,
    required this.submitting,
    required this.currentLocationIsSaved,
    required this.savingAddress,
    required this.onSaveAddress,
    required this.isScheduled,
    required this.scheduledFor,
    required this.recurrence,
    required this.onScheduleModeChanged,
    required this.onPickDateTime,
    required this.onRecurrenceChanged,
    required this.onToggleWasteType,
    required this.onPhoneChanged,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 4,
          margin:
          const EdgeInsets.only(top: AppSizes.spacing12, bottom: AppSizes.spacing12),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            children: [
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
                      child: resolvingAddress
                          ? Text('Locating address…', style: context.textTheme.bodySmall)
                          : Text(
                        address ??
                            '${location.latitude.toStringAsFixed(5)}, '
                                '${location.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!resolvingAddress)
                      savingAddress
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: currentLocationIsSaved ? null : onSaveAddress,
                        tooltip: currentLocationIsSaved ? 'Already saved' : 'Save this address',
                        icon: Icon(
                          currentLocationIsSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.spacing16),
              Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: 'Now',
                      icon: Icons.bolt_rounded,
                      selected: !isScheduled,
                      onTap: () => onScheduleModeChanged(false),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: _ModeChip(
                      label: 'Schedule',
                      icon: Icons.calendar_month_rounded,
                      selected: isScheduled,
                      onTap: () => onScheduleModeChanged(true),
                    ),
                  ),
                ],
              ),
              if (isScheduled) ...[
                const SizedBox(height: AppSizes.spacing16),
                Text(
                  'When',
                  style: context.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSizes.spacing8),
                OutlinedButton.icon(
                  onPressed: onPickDateTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(
                    scheduledFor == null ? 'Pick a date & time' : _formatScheduled(scheduledFor!),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing16),
                Text(
                  'Repeat',
                  style: context.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSizes.spacing8),
                Wrap(
                  spacing: AppSizes.spacing8,
                  runSpacing: AppSizes.spacing8,
                  children: PickupRecurrence.values.map((r) {
                    return ChoiceChip(
                      label: Text(r.label),
                      selected: recurrence == r,
                      onSelected: (_) => onRecurrenceChanged(r),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: AppSizes.spacing16),
              Text(
                'Contact phone number',
                style: context.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSizes.spacing8),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                onChanged: onPhoneChanged,
                decoration: const InputDecoration(
                  hintText: 'e.g. 024 123 4567',
                  prefixIcon: Icon(Icons.call_outlined, size: 20),
                ),
              ),
              const SizedBox(height: AppSizes.spacing16),
              Text(
                'Photo of the waste (optional)',
                style: context.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSizes.spacing8),
              if (photo == null)
                OutlinedButton.icon(
                  onPressed: onPickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Add a photo'),
                )
              else
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      child: Image.file(
                        photo!,
                        height: 96,
                        width: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onRemovePhoto,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSizes.spacing16),
              Text(
                'Waste type',
                style: context.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSizes.spacing8),
              Wrap(
                spacing: AppSizes.spacing8,
                runSpacing: AppSizes.spacing8,
                children: WasteType.values.map((type) {
                  final selected = selectedWasteTypes.contains(type);
                  return FilterChip(
                    label: Text(type.label),
                    selected: selected,
                    onSelected: (_) => onToggleWasteType(type),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.paddingL,
            AppSizes.spacing12,
            AppSizes.paddingL,
            AppSizes.paddingL,
          ),
          child: CustomButton(
            text: isScheduled ? 'Confirm schedule' : 'Request pickup here',
            icon: isScheduled ? Icons.calendar_month_rounded : Icons.recycling_rounded,
            loading: submitting,
            onPressed: onSubmit,
          ),
        ),
      ],
    );
  }
}

String _formatScheduled(DateTime dateTime) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour < 12 ? 'AM' : 'PM';
  return '${dateTime.day} ${months[dateTime.month - 1]}, $hour:$minute $period';
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppSizes.durationFast,
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.grey50,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}