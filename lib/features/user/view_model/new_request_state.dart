import 'dart:io';

import '../../../core/models/geo_point_data.dart';
import '../../../core/utils/enums.dart';

class NewRequestState {
  final GeoPointData? location;
  final Set<WasteType> selectedWasteTypes;
  final String phone;
  final File? photo;
  final bool submitting;
  final String? error;
  final String? createdRequestId;

  // Scheduling — a request can be submitted immediately (the default) or
  // set up as a one-time/recurring schedule instead.
  final bool isScheduled;
  final DateTime? scheduledFor;
  final PickupRecurrence recurrence;
  final String? createdScheduleId;

  const NewRequestState({
    this.location,
    this.selectedWasteTypes = const {},
    this.phone = '',
    this.photo,
    this.submitting = false,
    this.error,
    this.createdRequestId,
    this.isScheduled = false,
    this.scheduledFor,
    this.recurrence = PickupRecurrence.once,
    this.createdScheduleId,
  });

  NewRequestState copyWith({
    GeoPointData? location,
    Set<WasteType>? selectedWasteTypes,
    String? phone,
    File? Function()? photo,
    bool? submitting,
    String? Function()? error,
    String? Function()? createdRequestId,
    bool? isScheduled,
    DateTime? Function()? scheduledFor,
    PickupRecurrence? recurrence,
    String? Function()? createdScheduleId,
  }) {
    return NewRequestState(
      location: location ?? this.location,
      selectedWasteTypes: selectedWasteTypes ?? this.selectedWasteTypes,
      phone: phone ?? this.phone,
      photo: photo != null ? photo() : this.photo,
      submitting: submitting ?? this.submitting,
      error: error != null ? error() : this.error,
      createdRequestId:
      createdRequestId != null ? createdRequestId() : this.createdRequestId,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledFor: scheduledFor != null ? scheduledFor() : this.scheduledFor,
      recurrence: recurrence ?? this.recurrence,
      createdScheduleId:
      createdScheduleId != null ? createdScheduleId() : this.createdScheduleId,
    );
  }
}