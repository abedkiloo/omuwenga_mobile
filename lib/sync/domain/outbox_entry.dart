enum OutboxStatus {
  pending,
  inFlight,
  synced,
  failed,
}

/// One queued mutation waiting to reach the server.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.clientResourceId,
    required this.idempotencyKey,
    required this.method,
    required this.path,
    required this.bodyJson,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    this.nextAttemptAt,
    this.lastError,
    this.humanError,
  });

  final String id;
  final String clientResourceId;

  /// Stable across retries — sent as `Idempotency-Key`.
  final String idempotencyKey;
  final String method;
  final String path;
  final String bodyJson;
  final OutboxStatus status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final String? humanError;

  bool get isPendingWork =>
      status == OutboxStatus.pending || status == OutboxStatus.inFlight;

  bool get isFailed => status == OutboxStatus.failed;

  OutboxEntry copyWith({
    OutboxStatus? status,
    int? attemptCount,
    DateTime? nextAttemptAt,
    String? lastError,
    String? humanError,
    bool clearError = false,
  }) {
    return OutboxEntry(
      id: id,
      clientResourceId: clientResourceId,
      idempotencyKey: idempotencyKey,
      method: method,
      path: path,
      bodyJson: bodyJson,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      humanError: clearError ? null : (humanError ?? this.humanError),
    );
  }
}

class EnqueueMutation {
  const EnqueueMutation({
    required this.method,
    required this.path,
    required this.bodyJson,
    this.clientResourceId,
    this.idempotencyKey,
  });

  final String method;
  final String path;
  final String bodyJson;
  final String? clientResourceId;
  final String? idempotencyKey;
}
