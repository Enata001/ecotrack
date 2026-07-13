import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:flutter/foundation.dart';

import '../exceptions/result.dart';
import '../models/geo_point_data.dart';
import '../models/receipt.dart';
import '../models/scheduled_pickup.dart';
import '../models/waste_request.dart';
import '../services/firebase/cloud_functions_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';
import '../utils/enums.dart';

class RequestRepository {
  final FirestoreService _firestore;
  final CloudFunctionsService _functions;
  final StorageService _storage;

  RequestRepository(this._firestore, this._functions, this._storage);

  Future<Result<String>> createRequest({
    required String userId,
    required GeoPointData location,
    String? address,
    required List<WasteType> wasteTypes,
    required String contactPhone,
    File? photo,
    // Lets "retry a cancelled request" carry the original photo forward
    // without needing the local file again — we already have the URL.
    String? existingPhotoUrl,
  }) async {
    try {
      final request = WasteRequest(
        id: '',
        userId: userId,
        collectorId: null,
        location: location,
        address: address,
        wasteTypes: wasteTypes,
        status: RequestStatus.pending,
        createdAt: DateTime.now(),
        completedAt: null,
        contactPhone: contactPhone,
        photoUrl: existingPhotoUrl,
      );

      // Generate the doc ID up front (no write yet) so a photo, if any,
      // can be uploaded to a Storage path matching this request's id.
      final docRef = _firestore.wasteRequests.doc();
      await docRef.set(request.toCreateMap());

      if (photo != null) {
        try {
          final url = await _storage.uploadRequestPhoto(
            requestId: docRef.id,
            file: photo,
          );
          await docRef.update({'photoUrl': url});
        } catch (e) {
          debugPrint('Photo upload failed for ${docRef.id}: $e');
          // The request itself was created successfully — a failed photo
          // upload shouldn't fail the whole submission.
        }
      }

      return Success(docRef.id);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  Stream<WasteRequest?> watchRequest(String requestId) {
    return _firestore.wasteRequests.doc(requestId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return WasteRequest.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<WasteRequest>> watchUserRequests(String userId) {
    return _firestore.wasteRequests
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => WasteRequest.fromMap(d.id, d.data())).toList());
  }

  /// All requests a collector has ever been assigned to (accepted through
  /// to completed/cancelled) — this is the collector-side "history."
  Stream<List<WasteRequest>> watchCollectorRequests(String collectorId) {
    return _firestore.wasteRequests
        .where('collectorId', isEqualTo: collectorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => WasteRequest.fromMap(d.id, d.data())).toList());
  }

  Stream<List<WasteRequest>> watchPendingRequests() {
    return _firestore.wasteRequests
        .where('status', isEqualTo: RequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => WasteRequest.fromMap(d.id, d.data())).toList());
  }

  Future<Result<void>> acceptRequest(String requestId) async {
    try {
      await _functions.acceptRequest(requestId);
      return const Success(null);
    } catch (e) {
      debugPrint('acceptRequest failed for $requestId: $e');
      return Failure(AppException(message: _cloudFunctionErrorMessage(e)));
    }
  }

  Future<Result<void>> declineRequest(String requestId) async {
    try {
      await _functions.declineRequest(requestId);
      return const Success(null);
    } catch (e) {
      debugPrint('declineRequest failed for $requestId: $e');
      return Failure(AppException(message: _cloudFunctionErrorMessage(e)));
    }
  }

  Future<Result<void>> cancelRequest(String requestId) async {
    try {
      await _functions.cancelRequest(requestId);
      return const Success(null);
    } catch (e) {
      debugPrint('cancelRequest failed for $requestId: $e');
      return Failure(AppException(message: _cloudFunctionErrorMessage(e)));
    }
  }

  Future<Result<void>> startEnroute(String requestId) async {
    try {
      await _functions.startEnroute(requestId);
      return const Success(null);
    } catch (e) {
      debugPrint('startEnroute failed for $requestId: $e');
      return Failure(AppException(message: _cloudFunctionErrorMessage(e)));
    }
  }

  Future<Result<void>> markArrived(String requestId) async {
    try {
      await _functions.markArrived(requestId);
      return const Success(null);
    } catch (e) {
      debugPrint('markArrived failed for $requestId: $e');
      return Failure(AppException(message: _cloudFunctionErrorMessage(e)));
    }
  }

  /// Cloud Functions surface errors as [FirebaseFunctionsException] with a
  /// `.code` matching whatever HttpsError code the function threw. Branch
  /// on that rather than string-matching `.toString()` (fragile), and fall
  /// back to including the actual message rather than a single generic
  /// string that swallows every failure mode identically.
  String _cloudFunctionErrorMessage(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'already-exists':
          return 'Already taken.';
        case 'not-found':
          return 'This request no longer exists.';
        case 'permission-denied':
          return "You don't have permission to do that.";
        case 'failed-precondition':
          return e.message ?? 'That action is not allowed right now.';
        case 'unauthenticated':
          return 'Please sign in again.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Network issue reaching the server — please try again.';
        default:
          return e.message ?? 'Something went wrong (${e.code}).';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  Future<List<WasteRequest>> fetchActiveRequests(List<String> ids) async {
    if (ids.isEmpty) return [];
    final docs = await Future.wait(
      ids.map((id) => _firestore.wasteRequests.doc(id).get()),
    );
    return docs
        .where((d) => d.exists)
        .map((d) => WasteRequest.fromMap(d.id, d.data()!))
        .where(
          (r) =>
      r.status != RequestStatus.completed &&
          r.status != RequestStatus.cancelled,
    )
        .toList();
  }

  Future<Result<Map<String, dynamic>>> optimizeRoute({
    required GeoPointData origin,
    required List<WasteRequest> stops,
  }) async {
    try {
      final result = await _functions.optimizeRoute(
        origin: {'lat': origin.latitude, 'lng': origin.longitude},
        stops: stops
            .map(
              (s) => {
            'id': s.id,
            'lat': s.location.latitude,
            'lng': s.location.longitude,
          },
        )
            .toList(),
      );
      return Success(result);
    } catch (e) {
      debugPrint('optimizeRoute failed: $e');
      return Failure(AppException(message: 'Could not optimize route.'));
    }
  }

  Future<Result<Map<String, dynamic>>> completePickup({
    required String requestId,
    required double weightKg,
    required WasteType wasteType,
  }) async {
    try {
      final result = await _functions.completePickup(
        requestId: requestId,
        weightKg: weightKg,
        wasteType: wasteType.name,
      );
      return Success(result);
    } catch (e) {
      debugPrint('completePickup failed for $requestId: $e');
      return Failure(AppException(message: _cloudFunctionErrorMessage(e)));
    }
  }

  Future<Receipt?> fetchReceiptForRequest(String requestId) async {
    final snap = await _firestore.receipts
        .where('requestId', isEqualTo: requestId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Receipt.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  /// Rates the other party on a completed pickup (a user rating their
  /// collector, or a collector rating the user). The Cloud Function
  /// enforces one rating per side per request and updates the rated
  /// account's running average.
  Future<Result<void>> submitRating({
    required String requestId,
    required int stars,
    String? comment,
  }) async {
    try {
      await _functions.submitRating(
        requestId: requestId,
        stars: stars,
        comment: comment,
      );
      return const Success(null);
    } catch (e) {
      debugPrint('submitRating failed for $requestId: $e');
      return Failure(AppException(message: _ratingErrorMessage(e)));
    }
  }

  String _ratingErrorMessage(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'already-exists':
          return "You've already rated this pickup.";
        case 'not-found':
          return 'This request no longer exists.';
        case 'failed-precondition':
          return e.message ?? 'This pickup can\'t be rated yet.';
        case 'permission-denied':
          return "You weren't part of this pickup.";
        case 'unauthenticated':
          return 'Please sign in again.';
        default:
          return e.message ?? 'Could not submit your rating.';
      }
    }
    return 'Could not submit your rating. Please try again.';
  }

  // ---------------------------------------------------------------------
  // Scheduled / recurring pickups
  // ---------------------------------------------------------------------

  /// Creates a schedule "template" rather than a live request. The
  /// `runScheduledPickups` Cloud Function turns each due schedule into a
  /// real [WasteRequest] (which then notifies nearby collectors exactly
  /// like an on-demand one) and advances or deactivates it afterward.
  Future<Result<String>> createSchedule({
    required String userId,
    required GeoPointData location,
    String? address,
    required List<WasteType> wasteTypes,
    required String contactPhone,
    required PickupRecurrence recurrence,
    required DateTime startAt,
    File? photo,
  }) async {
    try {
      final schedule = ScheduledPickup(
        id: '',
        userId: userId,
        location: location,
        address: address,
        wasteTypes: wasteTypes,
        contactPhone: contactPhone,
        recurrence: recurrence,
        nextRunAt: startAt,
      );

      final docRef = _firestore.scheduledPickups.doc();
      await docRef.set(schedule.toCreateMap());

      if (photo != null) {
        try {
          final url = await _storage.uploadSchedulePhoto(scheduleId: docRef.id, file: photo);
          await docRef.update({'photoUrl': url});
        } catch (e) {
          debugPrint('Schedule photo upload failed for ${docRef.id}: $e');
        }
      }

      return Success(docRef.id);
    } catch (e) {
      return Failure(AppException(message: 'Could not create the schedule.'));
    }
  }

  Stream<List<ScheduledPickup>> watchUserSchedules(String userId) {
    return _firestore.scheduledPickups
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => ScheduledPickup.fromMap(d.id, d.data())).toList());
  }

  Future<Result<void>> cancelSchedule(String scheduleId) async {
    try {
      await _firestore.scheduledPickups.doc(scheduleId).delete();
      return const Success(null);
    } catch (e) {
      return Failure(AppException(message: 'Could not cancel the schedule.'));
    }
  }

 Future<Result<void>> updateSchedule({
    required String scheduleId,
    List<WasteType>? wasteTypes,
    String? contactPhone,
    PickupRecurrence? recurrence,
    DateTime? nextRunAt,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (wasteTypes != null) {
        updates['wasteTypes'] = wasteTypes.map((e) => e.name).toList();
      }
      if (contactPhone != null) updates['contactPhone'] = contactPhone;
      if (recurrence != null) updates['recurrence'] = recurrence.name;
      if (nextRunAt != null) updates['nextRunAt'] = Timestamp.fromDate(nextRunAt);
      if (updates.isEmpty) return const Success(null);

      await _firestore.scheduledPickups.doc(scheduleId).update(updates);
      return const Success(null);
    } catch (e) {
      return Failure(AppException(message: 'Could not update the schedule.'));
    }
  }
}