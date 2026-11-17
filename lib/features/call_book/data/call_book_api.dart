import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_message.dart';
import '../../../core/result/result.dart';
import '../domain/call_book.dart';

/// HTTP access to the shared call book.
///
/// Reads one page of customers who still need a call, holds a customer while
/// the number is copied, and records the result. Error text comes from the
/// server and is not given a phone number by this client.
class CallBookApi {
  CallBookApi(this._client);

  final ApiClient _client;

  /// Load one day page.
  ///
  /// [weekday] is 0–4. [page] is 1 or more. [pageSize] is clamped to 1–10.
  /// The request always asks for `not_called`, so a recorded customer is
  /// absent unless their call-later time is due.
  ///
  /// Returns the page, or a failure whose message has no added phone number.
  Future<Result<CallBookPageData>> fetch({
    required int weekday,
    int page = 1,
    int pageSize = kCallBookPageSize,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeSize = pageSize.clamp(1, kCallBookPageSize);
    final safeDay = weekday.clamp(0, 4);
    final query = [
      'scope=week',
      'status=not_called',
      'page=$safePage',
      'page_size=$safeSize',
      'weekday=$safeDay',
    ].join('&');
    final response = await _client.get('sales/call-book/?$query');
    return _decode(response, CallBookPageData.fromJson);
  }

  /// Record the cell-phone call.
  ///
  /// [customerId] is a positive customer id. [outcome] is `called`,
  /// `ask_later`, `no_answer`, or `unreachable`. [summary] is 0–500
  /// characters. [followUpOn] is blank or `YYYY-MM-DD`. [followUpTime] is
  /// blank or `HH:MM`, and is required by the server for call later.
  ///
  /// Returns success, or the server message. Does not add a phone number.
  Future<Result<bool>> mark({
    required int customerId,
    required String outcome,
    String summary = '',
    String followUpOn = '',
    String followUpTime = '',
  }) async {
    final response = await _client.post(
      'sales/call-book/$customerId/mark/',
      body: {
        'outcome': outcome,
        'request_summary': summary.length > 500 ? summary.substring(0, 500) : summary,
        'follow_up_on': followUpOn,
        'follow_up_time': followUpTime,
      },
    );
    return _ok(response);
  }

  /// Reserve the customer while the number is copied.
  ///
  /// [customerId] is a positive customer id. The hold lasts the minutes
  /// configured on the server (1–30).
  ///
  /// Returns success, or the server message.
  Future<Result<bool>> hold(int customerId) async {
    final response = await _client.post('sales/call-book/$customerId/hold/');
    return _ok(response);
  }

  /// Parse a JSON object body.
  ///
  /// [response] is the HTTP result. [parse] builds the value from the map.
  /// A non-2xx body is turned into its error text and is not given a phone.
  ///
  /// Returns the parsed value, or a failure.
  Result<T> _decode<T>(
    Result<http.Response> response,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (response.isFailure) {
      final failure = response as Failure<http.Response>;
      return Failure(failure.error, failure.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(apiErrorMessage(res.body, fallback: 'Could not open the call centre.'));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return Failure('Could not open the call centre.');
    }
    return Success(parse(Map<String, dynamic>.from(decoded)));
  }

  /// Accept a 2xx body and ignore its payload.
  ///
  /// [response] is the HTTP result. A failure keeps the server message.
  ///
  /// Returns true, or a failure.
  Result<bool> _ok(Result<http.Response> response) {
    if (response.isFailure) {
      final failure = response as Failure<http.Response>;
      return Failure(failure.error, failure.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(
        apiErrorMessage(res.body, fallback: 'Could not record this call.'),
      );
    }
    return const Success(true);
  }
}
