import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/waste_request.dart';
import '../../../core/providers.dart';
import 'incoming_requests_state.dart';

class IncomingRequestsViewModel extends Notifier<IncomingRequestsState> {
  @override
  IncomingRequestsState build() => const IncomingRequestsState();

  Stream<List<WasteRequest>> watchPending() {
    return ref.read(requestRepositoryProvider).watchPendingRequests();
  }

  Future<bool> accept(String requestId) async {
    if (state.accepting) return false;
    state = state.copyWith(
      accepting: true,
      acceptingRequestId: () => requestId,
      error: () => null,
    );

    final result = await ref.read(requestRepositoryProvider).acceptRequest(requestId);

    return result.map(
      onSuccess: (_) {
        state = state.copyWith(accepting: false, acceptingRequestId: () => null);
        return true;
      },
      onError: (error) {
        state = state.copyWith(
          accepting: false,
          acceptingRequestId: () => null,
          error: () => error.message,
        );
        return false;
      },
    );
  }

  Future<bool> decline(String requestId) async {
    if (state.accepting) return false;
    state = state.copyWith(
      accepting: true,
      acceptingRequestId: () => requestId,
      error: () => null,
    );

    final result = await ref.read(requestRepositoryProvider).declineRequest(requestId);

    return result.map(
      onSuccess: (_) {
        state = state.copyWith(accepting: false, acceptingRequestId: () => null);
        return true;
      },
      onError: (error) {
        state = state.copyWith(
          accepting: false,
          acceptingRequestId: () => null,
          error: () => error.message,
        );
        return false;
      },
    );
  }
}

final incomingRequestsViewModelProvider = NotifierProvider.autoDispose<
    IncomingRequestsViewModel, IncomingRequestsState>(
  IncomingRequestsViewModel.new,
);
