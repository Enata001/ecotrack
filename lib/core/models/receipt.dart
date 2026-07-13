import 'package:cloud_firestore/cloud_firestore.dart';

class Receipt {
  final String id;
  final String requestId;
  final double weightKg;
  final String wasteType;
  final double impactScore;
  final DateTime timestamp;

  const Receipt({
    required this.id,
    required this.requestId,
    required this.weightKg,
    required this.wasteType,
    required this.impactScore,
    required this.timestamp,
  });

  factory Receipt.fromMap(String id, Map<String, dynamic> map) {
    return Receipt(
      id: id,
      requestId: map['requestId'] ?? '',
      weightKg: (map['weightKg'] ?? 0).toDouble(),
      wasteType: map['wasteType'] ?? '',
      impactScore: (map['impactScore'] ?? 0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
