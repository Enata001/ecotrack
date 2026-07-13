import 'package:cloud_firestore/cloud_firestore.dart';

import 'geo_point_data.dart';
import '../utils/enums.dart';

class WasteRequest {
  final String id;
  final String userId;
  final String? collectorId;
  final GeoPointData location;
  final String? address;
  final List<WasteType> wasteTypes;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? arrivedAt;
  final List<String> declinedByCollectorIds;
  final String? contactPhone;
  final String? photoUrl;
  final bool ratedByUser;
  final bool ratedByCollector;

  const WasteRequest({
    required this.id,
    required this.userId,
    required this.collectorId,
    required this.location,
    this.address,
    required this.wasteTypes,
    required this.status,
    required this.createdAt,
    required this.completedAt,
    this.arrivedAt,
    this.declinedByCollectorIds = const [],
    this.contactPhone,
    this.photoUrl,
    this.ratedByUser = false,
    this.ratedByCollector = false,
  });

  factory WasteRequest.fromMap(String id, Map<String, dynamic> map) {
    return WasteRequest(
      id: id,
      userId: map['userId'] ?? '',
      collectorId: map['collectorId'],
      location: GeoPointData.fromGeoPoint(map['location'] as GeoPoint),
      address: map['address'],
      wasteTypes: (map['wasteTypes'] as List<dynamic>? ?? [])
          .map((e) => WasteType.fromString(e as String))
          .toList(),
      status: RequestStatus.fromString(map['status'] ?? 'pending'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      arrivedAt: (map['arrivedAt'] as Timestamp?)?.toDate(),
      declinedByCollectorIds:
      List<String>.from(map['declinedByCollectorIds'] ?? const []),
      contactPhone: map['contactPhone'],
      photoUrl: map['photoUrl'],
      ratedByUser: map['ratedByUser'] ?? false,
      ratedByCollector: map['ratedByCollector'] ?? false,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'userId': userId,
      'collectorId': null,
      'location': location.toGeoPoint(),
      'address': address,
      'wasteTypes': wasteTypes.map((e) => e.name).toList(),
      'status': RequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': null,
      'arrivedAt': null,
      'approachNotified': false,
      'declinedByCollectorIds': <String>[],
      'contactPhone': contactPhone,
      'photoUrl': photoUrl,
      'ratedByUser': false,
      'ratedByCollector': false,
    };
  }

  WasteRequest copyWith({RequestStatus? status, DateTime? arrivedAt}) {
    return WasteRequest(
      id: id,
      userId: userId,
      collectorId: collectorId,
      location: location,
      address: address,
      wasteTypes: wasteTypes,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      declinedByCollectorIds: declinedByCollectorIds,
      contactPhone: contactPhone,
      photoUrl: photoUrl,
      ratedByUser: ratedByUser,
      ratedByCollector: ratedByCollector,
    );
  }
}