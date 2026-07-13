import 'dart:convert';

class SavedAddress {
  final String label;
  final double latitude;
  final double longitude;

  const SavedAddress({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  String toJson() => jsonEncode({
    'label': label,
    'lat': latitude,
    'lng': longitude,
  });


  static SavedAddress? tryParse(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SavedAddress(
        label: map['label'] as String,
        latitude: (map['lat'] as num).toDouble(),
        longitude: (map['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  bool isNear(double lat, double lng) {
    return (latitude - lat).abs() < 0.0001 && (longitude - lng).abs() < 0.0001;
  }
}