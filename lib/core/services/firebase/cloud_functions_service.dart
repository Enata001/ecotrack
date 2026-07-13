import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions;

  CloudFunctionsService(this._functions);

  Future<Map<String, dynamic>> acceptRequest(String requestId) async {
    final callable = _functions.httpsCallable('acceptRequest');
    final result = await callable.call({'requestId': requestId});
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> startEnroute(String requestId) async {
    final callable = _functions.httpsCallable('startEnroute');
    final result = await callable.call({'requestId': requestId});
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> markArrived(String requestId) async {
    final callable = _functions.httpsCallable('markArrived');
    final result = await callable.call({'requestId': requestId});
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> declineRequest(String requestId) async {
    final callable = _functions.httpsCallable('declineRequest');
    final result = await callable.call({'requestId': requestId});
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> cancelRequest(String requestId) async {
    final callable = _functions.httpsCallable('cancelRequest');
    final result = await callable.call({'requestId': requestId});
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> completePickup({
    required String requestId,
    required double weightKg,
    required String wasteType,
  }) async {
    final callable = _functions.httpsCallable('completePickup');
    final result = await callable.call({
      'requestId': requestId,
      'weightKg': weightKg,
      'wasteType': wasteType,
    });
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> optimizeRoute({
    required Map<String, double> origin,
    required List<Map<String, dynamic>> stops,
  }) async {
    final callable = _functions.httpsCallable('optimizeRoute');
    final result = await callable.call({'origin': origin, 'stops': stops});
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> submitRating({
    required String requestId,
    required int stars,
    String? comment,
  }) async {
    final callable = _functions.httpsCallable('submitRating');
    final result = await callable.call({
      'requestId': requestId,
      'stars': stars,
      'comment': comment,
    });
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    final callable = _functions.httpsCallable('deleteAccount');
    final result = await callable.call();
    return Map<String, dynamic>.from(result.data);
  }
}