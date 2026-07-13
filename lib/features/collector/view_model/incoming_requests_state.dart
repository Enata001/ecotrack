class IncomingRequestsState {
  final bool accepting;
  final String? acceptingRequestId;
  final String? error;

  const IncomingRequestsState({
    this.accepting = false,
    this.acceptingRequestId,
    this.error,
  });

  IncomingRequestsState copyWith({
    bool? accepting,
    String? Function()? acceptingRequestId,
    String? Function()? error,
  }) {
    return IncomingRequestsState(
      accepting: accepting ?? this.accepting,
      acceptingRequestId: acceptingRequestId != null
          ? acceptingRequestId()
          : this.acceptingRequestId,
      error: error != null ? error() : this.error,
    );
  }
}
