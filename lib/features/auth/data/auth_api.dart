import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../../core/secure/token_store.dart';
import '../domain/auth_session.dart';

class AuthApi {
  // ignore: prefer_initializing_formals
  AuthApi({required ApiClient client, required TokenStore tokenStore})
    : _client = client,
      _tokenStore = tokenStore;

  final ApiClient _client;
  final TokenStore _tokenStore;

  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    final responseResult = await _client.post(
      'accounts/auth/login/',
      body: {'username': username, 'password': password},
      auth: false,
    );
    if (responseResult.isFailure) {
      final failure = responseResult as Failure<http.Response>;
      return Failure(failure.error, failure.stackTrace);
    }
    final res = responseResult.getOrThrow();

    if (res.statusCode == 401 || res.statusCode == 403) {
      return Failure(AuthFailure.invalidCredentials());
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(AuthFailure.server(safeMessage(res.body)));
    }
    final data = _decodeMap(res.body);
    if (data == null) {
      return Failure(AuthFailure.server('Unexpected login response.'));
    }
    final access = data['access']?.toString();
    final refresh = data['refresh']?.toString();
    if (access == null ||
        refresh == null ||
        access.isEmpty ||
        refresh.isEmpty) {
      return Failure(AuthFailure.server('Login response missing tokens.'));
    }
    await _tokenStore.writeTokens(access: access, refresh: refresh);
    return Success(AuthSession.fromAuthPayload(data));
  }

  Future<Result<AuthSession>> me() async {
    final responseResult = await _client.get('accounts/auth/me/');
    if (responseResult.isFailure) {
      final failure = responseResult as Failure<http.Response>;
      return Failure(failure.error, failure.stackTrace);
    }
    final res = responseResult.getOrThrow();
    if (res.statusCode == 401 || res.statusCode == 403) {
      return Failure(AuthFailure.sessionExpired());
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(AuthFailure.server(safeMessage(res.body)));
    }
    final data = _decodeMap(res.body);
    if (data == null) {
      return Failure(AuthFailure.server('Unexpected profile response.'));
    }
    return Success(AuthSession.fromAuthPayload(data));
  }

  Future<Result<void>> changePassword({
    required int userId,
    required String newPassword,
  }) async {
    final responseResult = await _client.post(
      'accounts/users/$userId/change_password/',
      body: {'new_password': newPassword},
    );
    if (responseResult.isFailure) {
      final failure = responseResult as Failure<http.Response>;
      return Failure(failure.error, failure.stackTrace);
    }
    final res = responseResult.getOrThrow();
    if (res.statusCode == 401) {
      return Failure(AuthFailure.sessionExpired());
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(AuthFailure.server(safeMessage(res.body)));
    }
    return const Success(null);
  }

  Future<Result<void>> logout() async {
    final refresh = await _tokenStore.readRefresh();
    if (refresh != null && refresh.isNotEmpty) {
      await _client.post('accounts/auth/logout/', body: {'refresh': refresh});
    }
    await _tokenStore.clear();
    return const Success(null);
  }

  static Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on Object {
      return null;
    }
    return null;
  }

  /// Never surface raw stack traces / token material to the UI.
  static String safeMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'] ?? decoded['detail'];
        if (error != null) return error.toString();
      }
    } on Object {
      // fall through
    }
    return 'Something went wrong. Please try again.';
  }
}

class AuthFailure implements Exception {
  AuthFailure._(this.message, {this.code = 'unknown'});

  factory AuthFailure.invalidCredentials() => AuthFailure._(
    'Invalid username or password.',
    code: 'invalid_credentials',
  );

  factory AuthFailure.sessionExpired() => AuthFailure._(
    'Session expired. Please sign in again.',
    code: 'session_expired',
  );

  factory AuthFailure.server(String message) =>
      AuthFailure._(message, code: 'server');

  final String message;
  final String code;

  @override
  String toString() => message;
}
