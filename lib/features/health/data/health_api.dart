import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';

class HealthStatus {
  const HealthStatus({required this.ok, required this.rawBody});

  final bool ok;
  final String rawBody;
}

class HealthApi {
  HealthApi(this._client);

  final ApiClient _client;

  /// Hits `GET /healthz/` on the API base (backend: `/api/healthz/`).
  Future<Result<HealthStatus>> check() async {
    final result = await _client.get('healthz/');
    return result.map((response) {
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      return HealthStatus(ok: ok, rawBody: response.body);
    });
  }
}
