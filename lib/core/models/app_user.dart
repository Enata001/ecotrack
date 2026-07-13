import 'package:cloud_firestore/cloud_firestore.dart';

import 'geo_point_data.dart';
import '../utils/enums.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final UserRole role;
  final List<String> savedAddresses;
  final double rating;
  final bool notificationsEnabled;
  final VehicleType? vehicleType;
  final GeoPointData? currentLocation;
  final bool isAvailable;
  final List<String> activeRequestIds;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    required this.role,
    this.savedAddresses = const [],
    this.rating = 5.0,
    this.notificationsEnabled = true,
    this.vehicleType,
    this.currentLocation,
    this.isAvailable = false,
    this.activeRequestIds = const [],
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      photoUrl: map['photoUrl'],
      role: UserRole.fromString(map['role'] ?? 'user'),
      savedAddresses: List<String>.from(map['savedAddresses'] ?? []),
      rating: (map['rating'] ?? 5.0).toDouble(),
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      vehicleType: map['vehicleType'] != null
          ? VehicleType.values.firstWhere(
            (e) => e.name == map['vehicleType'],
        orElse: () => VehicleType.van,
      )
          : null,
      currentLocation: map['currentLocation'] != null
          ? GeoPointData.fromGeoPoint(map['currentLocation'] as GeoPoint)
          : null,
      isAvailable: map['isAvailable'] ?? false,
      activeRequestIds: List<String>.from(map['activeRequestIds'] ?? []),
    );
  }

  Map<String, dynamic> toUserMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role.name,
      'savedAddresses': savedAddresses,
      'rating': rating,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  Map<String, dynamic> toCollectorMap() {
    return {
      'currentLocation': currentLocation?.toGeoPoint(),
      'isAvailable': isAvailable,
      'vehicleType': vehicleType?.name,
      'activeRequestIds': activeRequestIds,
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? photoUrl,
    bool? isAvailable,
    bool? notificationsEnabled,
    GeoPointData? currentLocation,
    List<String>? activeRequestIds,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role,
      savedAddresses: savedAddresses,
      rating: rating,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      vehicleType: vehicleType,
      currentLocation: currentLocation ?? this.currentLocation,
      isAvailable: isAvailable ?? this.isAvailable,
      activeRequestIds: activeRequestIds ?? this.activeRequestIds,
    );
  }
}