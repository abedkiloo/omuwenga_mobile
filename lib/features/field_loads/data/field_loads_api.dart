import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_message.dart';
import '../../../core/result/result.dart';
import '../domain/field_load.dart';

/// Failure from the field-load API. [message] is the server sentence only.
class FieldLoadsApiException implements Exception {
  FieldLoadsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// HTTP access to `/api/agents/field-loads/`.
///
/// Listing returns at most 100 loads. Selling and returning do not move shop
/// stock; accepting a return does, on the server.
class FieldLoadsApi {
  FieldLoadsApi(this._client);
  final ApiClient _client;

  Future<Result<FieldLoadBook>> list() {
    return _decode('agents/field-loads/', (json) => FieldLoadBook.fromJson(json));
  }

  /// Record [body] against an open load. [loadId] is a positive primary key.
  Future<Result<FieldLoad>> sell(int loadId, Map<String, dynamic> body) {
    return _post('agents/field-loads/$loadId/sell/', body);
  }

  /// Submit one returned quantity per line. Does not restock.
  Future<Result<FieldLoad>> submitReturn(int loadId, List<Map<String, dynamic>> lines) {
    return _post('agents/field-loads/$loadId/return/', {'lines': lines});
  }

  /// Approve quantities a sales person wrote. Shop stock leaves on the server.
  Future<Result<FieldLoad>> approveIssue(int loadId) {
    return _post('agents/field-loads/$loadId/approve-issue/', const {});
  }

  /// Send written quantities back. Shop stock does not move.
  Future<Result<FieldLoad>> declineIssue(int loadId) {
    return _post(
      'agents/field-loads/$loadId/decline-issue/',
      const {'note': 'Check the quantities'},
    );
  }

  /// Accept the count. The server restocks returned units.
  Future<Result<FieldLoad>> accept(int loadId) {
    return _post('agents/field-loads/$loadId/accept/', const {});
  }

  /// Send the count back. No stock movement.
  Future<Result<FieldLoad>> reject(int loadId) {
    return _post('agents/field-loads/$loadId/reject/', {'note': 'Count again'});
  }

  Future<Result<FieldLoad>> _post(String path, Map<String, dynamic> body) {
    return _decode(path, (json) => FieldLoad.fromJson(json), body: body);
  }

  Future<Result<T>> _decode<T>(
    String path,
    T Function(Map<String, dynamic> json) parse, {
    Map<String, dynamic>? body,
  }) async {
    final result = body == null
        ? await _client.get(path)
        : await _client.post(path, body: body);
    return result.when(
      success: (response) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            return Success(parse(Map<String, dynamic>.from(decoded)));
          }
          return Failure(FieldLoadsApiException('Could not read the field load.'));
        }
        return Failure(
          FieldLoadsApiException(
            apiErrorMessage(response.body, fallback: 'Could not update the field load.'),
          ),
        );
      },
      failure: (error, stackTrace) => Failure(error, stackTrace),
    );
  }
}
