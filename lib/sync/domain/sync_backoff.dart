/// Exponential backoff for outbox retries (capped).
class SyncBackoff {
  const SyncBackoff({
    this.base = const Duration(seconds: 1),
    this.cap = const Duration(seconds: 60),
  });

  final Duration base;
  final Duration cap;

  /// [attempt] is 1-based (first retry after failure → 1).
  Duration delayForAttempt(int attempt) {
    if (attempt <= 0) return Duration.zero;
    final multiplier = 1 << (attempt - 1).clamp(0, 16);
    final ms = base.inMilliseconds * multiplier;
    final capped = ms > cap.inMilliseconds ? cap.inMilliseconds : ms;
    return Duration(milliseconds: capped);
  }
}
