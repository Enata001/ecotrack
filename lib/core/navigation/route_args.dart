import '../models/app_user.dart';

class RequestTrackingArgs {
  final String requestId;
  const RequestTrackingArgs({required this.requestId});
}

class ReceiptArgs {
  final String requestId;
  const ReceiptArgs({required this.requestId});
}

class CompletePickupArgs {
  final String requestId;
  const CompletePickupArgs({required this.requestId});
}

class EditProfileArgs {
  final AppUser user;
  const EditProfileArgs({required this.user});
}