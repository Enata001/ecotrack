import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../models/geo_point_data.dart';

class Helpers {
  Helpers._();

  static const double nearbyRadiusMeters = 5000;

  /// Mirrors the Haversine calculation used server-side in
  /// firebase/functions/index.js so client-side "nearby" filtering matches
  /// what the onRequestCreated trigger considers nearby.
  static double distanceMeters(GeoPointData a, GeoPointData b) {
    const earthRadius = 6371000.0;
    double toRad(double deg) => deg * (math.pi / 180);

    final dLat = toRad(b.latitude - a.latitude);
    final dLng = toRad(b.longitude - a.longitude);
    final lat1 = toRad(a.latitude);
    final lat2 = toRad(b.latitude);

    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  static void showToast({
    required String message,
    ToastificationType type = ToastificationType.success,
    String? title,
  }) {
    toastification.show(
      type: type,
      title: title != null ? Text(title) : null,
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      primaryColor: switch (type) {
        ToastificationType.success => AppColors.success,
        ToastificationType.error => AppColors.error,
        ToastificationType.warning => AppColors.warning,
        _ => AppColors.info,
      },
    );
  }

  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  static String formatDistanceKm(double meters) {
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  static Future<bool> callPhone(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

 static Future<bool> openMapsNavigation(GeoPointData destination) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
          '&destination=${destination.latitude},${destination.longitude}'
          '&travelmode=driving',
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}