import 'package:cloud_firestore/cloud_firestore.dart';

import 'geo_point_data.dart';
import '../utils/enums.dart';


class ScheduledPickup {
  final String id;
  final String userId;
  final GeoPointData location;
  final String? address;
  final List<WasteType> wasteTypes;
  final String contactPhone;
  final String? photoUrl;
  final PickupRecurrence recurrence;
  final DateTime nextRunAt;
  final bool active;

  const ScheduledPickup({
    required this.id,
    required this.userId,
    required this.location,
    this.address,
    required this.wasteTypes,
    required this.contactPhone,
    this.photoUrl,
    required this.recurrence,
    required this.nextRunAt,
    this.active = true,
  });

  factory ScheduledPickup.fromMap(String id, Map<String, dynamic> map) {
    return ScheduledPickup(
      id: id,
      userId: map['userId'] ?? '',
      location: GeoPointData.fromGeoPoint(map['location'] as GeoPoint),
      address: map['address'],
      wasteTypes: (map['wasteTypes'] as List<dynamic>? ?? [])
          .map((e) => WasteType.fromString(e as String))
          .toList(),
      contactPhone: map['contactPhone'] ?? '',
      photoUrl: map['photoUrl'],
      recurrence: PickupRecurrence.fromString(map['recurrence'] ?? 'once'),
      nextRunAt: (map['nextRunAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      active: map['active'] ?? true,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'userId': userId,
      'location': location.toGeoPoint(),
      'address': address,
      'wasteTypes': wasteTypes.map((e) => e.name).toList(),
      'contactPhone': contactPhone,
      'photoUrl': photoUrl,
      'recurrence': recurrence.name,
      'nextRunAt': Timestamp.fromDate(nextRunAt),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}