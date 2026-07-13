import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/geo_point_data.dart';
import '../../../core/providers.dart';
import '../../../core/utils/enums.dart';
import 'active_route_state.dart';

class ActiveRouteViewModel extends Notifier<ActiveRouteState> {
  @override
  ActiveRouteState build() => const ActiveRouteState();

  Future<void> loadStops(String collectorId) async {
    state = state.copyWith(loading: true, error: () => null);

    final idsStream = ref.read(collectorRepositoryProvider).watchActiveRequestIds(
          collectorId,
        );
    final ids = await idsStream.first;
    final stops = await ref.read(requestRepositoryProvider).fetchActiveRequests(ids);

    state = state.copyWith(stops: stops, loading: false);
  }

  Future<void> optimize(GeoPointData origin) async {
    if (state.stops.isEmpty || state.optimizing) return;
    state = state.copyWith(optimizing: true, error: () => null);

    final result = await ref.read(requestRepositoryProvider).optimizeRoute(
          origin: origin,
          stops: state.stops,
        );

    result.map(
      onSuccess: (data) {
        final orderedIds = List<String>.from(data['orderedStopIds'] ?? []);
        final rawEta = Map<String, dynamic>.from(data['etaMinutes'] ?? {});
        final eta = rawEta.map((k, v) => MapEntry(k, (v as num).toInt()));

        final reordered = [
          for (final id in orderedIds)
            state.stops.firstWhere((s) => s.id == id),
        ];

        state = state.copyWith(
          stops: reordered.isEmpty ? state.stops : reordered,
          etaMinutes: eta,
          optimizing: false,
        );
      },
      onError: (error) {
        state = state.copyWith(optimizing: false, error: () => error.message);
      },
    );
  }

  Future<bool> startEnroute(String requestId) async {
    final result = await ref.read(requestRepositoryProvider).startEnroute(requestId);

    return result.map(
      onSuccess: (_) {
        final updatedStops = [
          for (final stop in state.stops)
            if (stop.id == requestId)
              stop.copyWith(status: RequestStatus.enroute)
            else
              stop,
        ];
        state = state.copyWith(stops: updatedStops);
        return true;
      },
      onError: (error) {
        state = state.copyWith(error: () => error.message);
        return false;
      },
    );
  }

  Future<bool> markArrived(String requestId) async {
    final result = await ref.read(requestRepositoryProvider).markArrived(requestId);

    return result.map(
      onSuccess: (_) {
        final updatedStops = [
          for (final stop in state.stops)
            if (stop.id == requestId)
              stop.copyWith(arrivedAt: DateTime.now())
            else
              stop,
        ];
        state = state.copyWith(stops: updatedStops);
        return true;
      },
      onError: (error) {
        state = state.copyWith(error: () => error.message);
        return false;
      },
    );
  }
}

final activeRouteViewModelProvider =
    NotifierProvider.autoDispose<ActiveRouteViewModel, ActiveRouteState>(
  ActiveRouteViewModel.new,
);
