/// Turns transport / HTTP failures into short user-facing copy.
String humanizeSyncError({required int? statusCode, required Object error}) {
  if (statusCode == 401 || statusCode == 403) {
    return 'Sign in again to sync this change.';
  }
  if (statusCode == 404) {
    return 'The server no longer accepts this action.';
  }
  if (statusCode == 409) {
    return 'This change conflicts with data already on the server.';
  }
  if (statusCode == 422 || statusCode == 400) {
    return 'The server rejected this change. Review and try again.';
  }
  if (statusCode != null && statusCode >= 500) {
    return 'Server is temporarily unavailable. Will retry.';
  }
  final raw = error.toString();
  if (raw.contains('SocketException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('Network is unreachable') ||
      raw.contains('Connection refused')) {
    return 'No connection. Saved locally — will sync when online.';
  }
  if (raw.contains('TimeoutException') || raw.contains('timed out')) {
    return 'Request timed out. Will retry.';
  }
  return 'Could not sync. Saved locally — will retry.';
}

bool isPermanentHttpFailure(int statusCode) {
  if (statusCode == 408 || statusCode == 429) return false;
  return statusCode >= 400 && statusCode < 500;
}
