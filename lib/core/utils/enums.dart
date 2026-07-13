enum UserRole {
  user,
  collector;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
          (e) => e.name == value,
      orElse: () => UserRole.user,
    );
  }
}

enum RequestStatus {
  pending,
  accepted,
  enroute,
  completed,
  cancelled;

  static RequestStatus fromString(String value) {
    return RequestStatus.values.firstWhere(
          (e) => e.name == value,
      orElse: () => RequestStatus.pending,
    );
  }
}

enum WasteType {
  general,
  recyclable,
  organic,
  electronic,
  hazardous,
  bulky;

  String get label {
    switch (this) {
      case WasteType.general:
        return 'General';
      case WasteType.recyclable:
        return 'Recyclable';
      case WasteType.organic:
        return 'Organic';
      case WasteType.electronic:
        return 'Electronic';
      case WasteType.hazardous:
        return 'Hazardous';
      case WasteType.bulky:
        return 'Bulky Items';
    }
  }

  static WasteType fromString(String value) {
    return WasteType.values.firstWhere(
          (e) => e.name == value,
      orElse: () => WasteType.general,
    );
  }
}

enum VehicleType {
  handcart,
  tricycle,
  van,
  truck;

  String get label {
    switch (this) {
      case VehicleType.handcart:
        return 'Handcart';
      case VehicleType.tricycle:
        return 'Tricycle';
      case VehicleType.van:
        return 'Van';
      case VehicleType.truck:
        return 'Truck';
    }
  }
}

enum PickupRecurrence {
  once,
  weekly,
  biweekly,
  monthly;

  String get label {
    switch (this) {
      case PickupRecurrence.once:
        return 'One time';
      case PickupRecurrence.weekly:
        return 'Weekly';
      case PickupRecurrence.biweekly:
        return 'Every 2 weeks';
      case PickupRecurrence.monthly:
        return 'Monthly';
    }
  }

  static PickupRecurrence fromString(String value) {
    return PickupRecurrence.values.firstWhere(
          (e) => e.name == value,
      orElse: () => PickupRecurrence.once,
    );
  }
}