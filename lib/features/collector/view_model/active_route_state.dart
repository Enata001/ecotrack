import '../../../core/models/waste_request.dart';

class ActiveRouteState {
  final List<WasteRequest> stops;
  final Map<String, int> etaMinutes;
  final bool optimizing;
  final bool loading;
  final String? error;

  const ActiveRouteState({
    this.stops = const [],
    this.etaMinutes = const {},
    this.optimizing = false,
    this.loading = false,
    this.error,
  });

  ActiveRouteState copyWith({
    List<WasteRequest>? stops,
    Map<String, int>? etaMinutes,
    bool? optimizing,
    bool? loading,
    String? Function()? error,
  }) {
    return ActiveRouteState(
      stops: stops ?? this.stops,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      optimizing: optimizing ?? this.optimizing,
      loading: loading ?? this.loading,
      error: error != null ? error() : this.error,
    );
  }
}
