import 'package:cloud_firestore/cloud_firestore.dart';

class GeoPointData {
  final double latitude;
  final double longitude;

  const GeoPointData({required this.latitude, required this.longitude});

  factory GeoPointData.fromGeoPoint(GeoPoint point) {
    return GeoPointData(latitude: point.latitude, longitude: point.longitude);
  }

  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);
}
