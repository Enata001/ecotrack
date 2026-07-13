import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/geo_point_data.dart';
import '../../../core/providers.dart';
import '../../../core/utils/enums.dart';
import 'new_request_state.dart';

class NewRequestViewModel extends Notifier<NewRequestState> {
  @override
  NewRequestState build() => const NewRequestState();

  void setLocation(GeoPointData location) {
    state = state.copyWith(location: location);
  }

  void toggleWasteType(WasteType type) {
    final updated = Set<WasteType>.from(state.selectedWasteTypes);
    if (!updated.add(type)) updated.remove(type);
    state = state.copyWith(selectedWasteTypes: updated);
  }

  void setPhone(String phone) {
    state = state.copyWith(phone: phone);
  }

  void setPhoto(File? photo) {
    state = state.copyWith(photo: () => photo);
  }

  void setScheduleMode(bool isScheduled) {
    state = state.copyWith(isScheduled: isScheduled);
  }

  void setScheduledFor(DateTime dateTime) {
    state = state.copyWith(scheduledFor: () => dateTime);
  }

  void setRecurrence(PickupRecurrence recurrence) {
    state = state.copyWith(recurrence: recurrence);
  }

  bool _validateCommon() {
    if (state.location == null || state.selectedWasteTypes.isEmpty) {
      state = state.copyWith(
        error: () => 'Pick a location and at least one waste type.',
      );
      return false;
    }
    if (state.phone.trim().isEmpty) {
      state = state.copyWith(error: () => 'A phone number is required.');
      return false;
    }
    return true;
  }

  Future<bool> submit(String userId, {String? address}) async {
    if (state.submitting) return false;
    if (!_validateCommon()) return false;

    state = state.copyWith(submitting: true, error: () => null);

    final result = await ref.read(requestRepositoryProvider).createRequest(
      userId: userId,
      location: state.location!,
      address: address,
      wasteTypes: state.selectedWasteTypes.toList(),
      contactPhone: state.phone.trim(),
      photo: state.photo,
    );

    return result.map(
      onSuccess: (id) {
        state = state.copyWith(submitting: false, createdRequestId: () => id);
        return true;
      },
      onError: (error) {
        state = state.copyWith(submitting: false, error: () => error.message);
        return false;
      },
    );
  }

  /// Creates a schedule "template" instead of a live request — see
  /// [RequestRepository.createSchedule] for how it later becomes a real
  /// request.
  Future<bool> submitSchedule(String userId, {String? address}) async {
    if (state.submitting) return false;
    if (!_validateCommon()) return false;

    final scheduledFor = state.scheduledFor;
    if (scheduledFor == null) {
      state = state.copyWith(error: () => 'Pick a date and time.');
      return false;
    }
    if (scheduledFor.isBefore(DateTime.now())) {
      state = state.copyWith(error: () => 'Pick a time in the future.');
      return false;
    }

    state = state.copyWith(submitting: true, error: () => null);

    final result = await ref.read(requestRepositoryProvider).createSchedule(
      userId: userId,
      location: state.location!,
      address: address,
      wasteTypes: state.selectedWasteTypes.toList(),
      contactPhone: state.phone.trim(),
      recurrence: state.recurrence,
      startAt: scheduledFor,
      photo: state.photo,
    );

    return result.map(
      onSuccess: (id) {
        state = state.copyWith(submitting: false, createdScheduleId: () => id);
        return true;
      },
      onError: (error) {
        state = state.copyWith(submitting: false, error: () => error.message);
        return false;
      },
    );
  }
}

final newRequestViewModelProvider =
NotifierProvider.autoDispose<NewRequestViewModel, NewRequestState>(
  NewRequestViewModel.new,
);