import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/network/api_client.dart';
import '../../core/result/result.dart';
import '../domain/human_error.dart';
import '../domain/outbox_entry.dart';
import '../domain/sync_backoff.dart';
import '../data/outbox_store.dart';

typedef OutboxHttpSender =
    Future<Result<http.Response>> Function(OutboxEntry entry);

/// Drains the outbox when online. Never reports success until the server accepts.
class SyncEngine {
  SyncEngine({
    required OutboxStore store,
    required OutboxHttpSender sender,
    SyncBackoff backoff = const SyncBackoff(),
    this.maxAttempts = 5,
    DateTime Function()? clock,
  }) : _store = store,
       _sender = sender,
       _backoff = backoff,
       _clock = clock ?? DateTime.now;

  final OutboxStore _store;
  final OutboxHttpSender _sender;
  final SyncBackoff _backoff;
  final int maxAttempts;
  final DateTime Function() _clock;

  bool _draining = false;

  Future<int> drainOnce() async {
    if (_draining) return 0;
    _draining = true;
    var synced = 0;
    try {
      final batch = await _store.listPending(readyBefore: _clock().toUtc());
      for (final entry in batch) {
        final ok = await _process(entry);
        if (ok) synced++;
      }
    } finally {
      _draining = false;
    }
    return synced;
  }

  Future<bool> _process(OutboxEntry entry) async {
    await _store.markInFlight(entry.id);
    final current = await _store.findById(entry.id);
    if (current == null) return false;

    try {
      final result = await _sender(current);

      if (result.isFailure) {
        final failure = result as Failure<http.Response>;
        return _onTransportFailure(current, failure.error);
      }

      final response = result.getOrThrow();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _store.markSynced(entry.id);
        return true;
      }

      final human = humanizeSyncError(
        statusCode: response.statusCode,
        error: response.body,
      );
      if (isPermanentHttpFailure(response.statusCode)) {
        await _store.markFailed(
          id: entry.id,
          lastError: 'HTTP ${response.statusCode}',
          humanError: human,
        );
        return false;
      }
      return _scheduleRetry(current, 'HTTP ${response.statusCode}', human);
    } on Object catch (error) {
      return _onTransportFailure(current, error);
    }
  }

  Future<bool> _onTransportFailure(OutboxEntry entry, Object error) {
    final human = humanizeSyncError(statusCode: null, error: error);
    return _scheduleRetry(entry, error.toString(), human);
  }

  Future<bool> _scheduleRetry(
    OutboxEntry entry,
    String lastError,
    String humanError,
  ) async {
    final nextAttempt = entry.attemptCount + 1;
    if (nextAttempt >= maxAttempts) {
      await _store.markFailed(
        id: entry.id,
        lastError: lastError,
        humanError: humanError,
      );
      return false;
    }
    final delay = _backoff.delayForAttempt(nextAttempt);
    await _store.markRetry(
      id: entry.id,
      attemptCount: nextAttempt,
      nextAttemptAt: _clock().toUtc().add(delay),
      lastError: lastError,
      humanError: humanError,
    );
    return false;
  }
}

/// Default sender that posts via [ApiClient] with a stable Idempotency-Key.
OutboxHttpSender apiOutboxSender(ApiClient client) {
  return (entry) async {
    final method = entry.method.toUpperCase();
    final multipart = _multipartPayload(entry.bodyJson);
    if (multipart != null && method == 'POST') {
      return client.postMultipart(
        entry.path,
        fields: multipart.fields,
        fileField: multipart.fileField,
        fileBytes: multipart.fileBytes,
        fileName: multipart.fileName,
        contentType: multipart.contentType,
        idempotencyKey: entry.idempotencyKey,
      );
    }
    if (method == 'POST') {
      return client.post(
        entry.path,
        body: _decodeBody(entry.bodyJson),
        idempotencyKey: entry.idempotencyKey,
      );
    }
    if (method == 'PUT') {
      return client.put(
        entry.path,
        body: _decodeBody(entry.bodyJson),
        idempotencyKey: entry.idempotencyKey,
      );
    }
    if (method == 'PATCH') {
      return client.patch(
        entry.path,
        body: _decodeBody(entry.bodyJson),
        idempotencyKey: entry.idempotencyKey,
      );
    }
    return Failure(UnsupportedError('Outbox method not supported: $method'));
  };
}

class _MultipartPayload {
  const _MultipartPayload({
    required this.fields,
    required this.fileField,
    required this.fileBytes,
    required this.fileName,
    required this.contentType,
  });

  final Map<String, String> fields;
  final String fileField;
  final List<int> fileBytes;
  final String fileName;
  final String contentType;
}

_MultipartPayload? _multipartPayload(String bodyJson) {
  if (bodyJson.isEmpty) return null;
  final decoded = jsonDecode(bodyJson);
  if (decoded is! Map || decoded['__multipart'] != true) return null;
  final filePath = decoded['file_path']?.toString();
  if (filePath == null || filePath.isEmpty) return null;
  List<int> bytes = const [];
  final file = File(filePath);
  if (file.existsSync()) {
    bytes = file.readAsBytesSync();
  }
  final rawFields = decoded['fields'];
  final fields = <String, String>{};
  if (rawFields is Map) {
    rawFields.forEach((k, v) => fields[k.toString()] = v.toString());
  }
  return _MultipartPayload(
    fields: fields,
    fileField: (decoded['file_field'] ?? 'image').toString(),
    fileBytes: bytes,
    fileName: (decoded['file_name'] ?? 'upload.bin').toString(),
    contentType: (decoded['content_type'] ?? 'application/octet-stream')
        .toString(),
  );
}

Map<String, dynamic>? _decodeBody(String bodyJson) {
  if (bodyJson.isEmpty) return null;
  final decoded = jsonDecode(bodyJson);
  if (decoded is Map) {
    final map = Map<String, dynamic>.from(decoded);
    map.remove('__multipart');
    return map;
  }
  return null;
}
