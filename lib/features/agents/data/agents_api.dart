import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../../sync/domain/client_uuid.dart';
import '../../../sync/domain/outbox_entry.dart';
import '../../../sync/data/outbox_store.dart';
import '../domain/site_visit.dart';

class AgentsApiException implements Exception {
  AgentsApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AgentsApi {
  AgentsApi(this._client, {ClientUuid? ids});

  final ApiClient _client;
  final ClientUuid _ids = ClientUuid();

  Future<Result<SiteVisitConfig>> fetchConfig() async {
    final res = await _client.get('agents/sites/config/');
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(AgentsApiException('Config failed (${response.statusCode})'));
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(AgentsApiException('Invalid config payload'));
      }
      return Success(SiteVisitConfig.fromJson(Map<String, dynamic>.from(data)));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<Map<String, dynamic>>> createSite({
    required SitePin pin,
    String landmark = '',
    String label = '',
    int? customerId,
    String? clientUuid,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'latitude': pin.latitude.toStringAsFixed(7),
      'longitude': pin.longitude.toStringAsFixed(7),
      if (pin.accuracy != null) 'accuracy': pin.accuracy,
      'landmark': landmark,
      'label': label.isNotEmpty ? label : pin.label,
      if (customerId != null) 'customer': customerId,
      'client_uuid': clientUuid ?? _ids.next(),
    };
    final res = await _client.post(
      'agents/sites/',
      body: body,
      idempotencyKey: idempotencyKey ?? _ids.next(),
    );
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(AgentsApiException('Create site failed (${response.statusCode})'));
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(AgentsApiException('Invalid site payload'));
      }
      return Success(Map<String, dynamic>.from(data));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<Map<String, dynamic>>> patchSite(
    int siteId, {
    int? customerId,
    String? landmark,
    String? label,
  }) async {
    final body = <String, dynamic>{
      if (customerId != null) 'customer': customerId,
      if (landmark != null) 'landmark': landmark,
      if (label != null) 'label': label,
    };
    final res = await _client.patch('agents/sites/$siteId/', body: body);
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(AgentsApiException('Update site failed (${response.statusCode})'));
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(AgentsApiException('Invalid site payload'));
      }
      return Success(Map<String, dynamic>.from(data));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<Map<String, dynamic>>> finalizeSite(int siteId) async {
    final res = await _client.post('agents/sites/$siteId/finalize/');
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(AgentsApiException('Finalize failed (${response.statusCode}): ${response.body}'));
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(AgentsApiException('Invalid finalize payload'));
      }
      return Success(Map<String, dynamic>.from(data));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  /// Enqueue multipart media upload for offline honesty.
  Future<OutboxEntry> enqueueMediaUpload({
    required OutboxStore outbox,
    required int siteId,
    required LocalSitePhoto photo,
    required String idempotencyKey,
  }) {
    final payload = jsonEncode({
      '__multipart': true,
      'file_field': 'image',
      'file_path': photo.path,
      'file_name': photo.path.split('/').last,
      'content_type': 'image/jpeg',
      'fields': {
        if (photo.caption.isNotEmpty) 'caption': photo.caption,
        'client_uuid': photo.id,
      },
    });
    return outbox.enqueue(
      EnqueueMutation(
        method: 'POST',
        path: 'agents/sites/$siteId/media/',
        bodyJson: payload,
        clientResourceId: photo.id,
        idempotencyKey: idempotencyKey,
      ),
    );
  }
}
