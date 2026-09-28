import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/appraisal.dart';

class AppraisalsApiException implements Exception {
  AppraisalsApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AppraisalsApi {
  AppraisalsApi(this._client);
  final ApiClient _client;

  Future<Result<AppraisalSnapshot>> me() async {
    final res = await _client.get('appraisals/me/');
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        AppraisalsApiException('Load appraisal failed (${response.statusCode})'),
      );
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(AppraisalsApiException('Invalid appraisal payload'));
      }
      return Success(AppraisalSnapshot.fromJson(Map<String, dynamic>.from(data)));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }
}
