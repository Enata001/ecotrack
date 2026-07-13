import '../exceptions/result.dart';
import '../models/geo_point_data.dart';
import '../services/firebase/firestore_service.dart';

class CollectorRepository {
  final FirestoreService _firestore;

  CollectorRepository(this._firestore);

  Future<Result<void>> setAvailability({
    required String collectorId,
    required bool isAvailable,
  }) async {
    try {
      await _firestore.collectors.doc(collectorId).update({
        'isAvailable': isAvailable,
      });
      return const Success(null);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  Future<Result<void>> updateLocation({
    required String collectorId,
    required GeoPointData location,
  }) async {
    try {
      await _firestore.collectors.doc(collectorId).update({
        'currentLocation': location.toGeoPoint(),
      });
      return const Success(null);
    } catch (e) {
      return Failure(AppException(message: e.toString()));
    }
  }

  Stream<List<String>> watchActiveRequestIds(String collectorId) {
    return _firestore.collectors.doc(collectorId).snapshots().map((doc) {
      if (!doc.exists) return <String>[];
      return List<String>.from(doc.data()?['activeRequestIds'] ?? []);
    });
  }

  Stream<GeoPointData?> watchCollectorLocation(String collectorId) {
    return _firestore.collectors.doc(collectorId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null || data['currentLocation'] == null) return null;
      return GeoPointData.fromGeoPoint(data['currentLocation']);
    });
  }

  Stream<bool> watchIsAvailable(String collectorId) {
    return _firestore.collectors.doc(collectorId).snapshots().map((doc) {
      return doc.data()?['isAvailable'] as bool? ?? false;
    });
  }
}
