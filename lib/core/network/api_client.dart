import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../env/app_env.dart';
import '../result/result.dart';
import '../secure/token_store.dart';

typedef SessionExpiredCallback = FutureOr<void> Function();

/// HTTP client with JWT attach + single-flight refresh (matches web SPA).
class ApiClient {
  // ignore: prefer_initializing_formals
  ApiClient({
    required AppEnv env,
    required TokenStore tokenStore,
    http.Client? httpClient,
    SessionExpiredCallback? onSessionExpired,
  }) : _env = env,
       _tokenStore = tokenStore,
       _http = httpClient ?? http.Client(),
       _onSessionExpired = onSessionExpired;

  final AppEnv _env;
  final TokenStore _tokenStore;
  final http.Client _http;
  final SessionExpiredCallback? _onSessionExpired;

  Future<String?>? _refreshInFlight;

  String get baseUrl => _env.apiBaseUrl;

  Uri resolve(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$baseUrl/$normalized');
  }

  bool _isAuthBypass(String path) {
    return path.contains('token/refresh') ||
        path.contains('accounts/auth/logout') ||
        path.contains('accounts/auth/login') ||
        path.contains('auth/login');
  }

  Future<Map<String, String>> _headers({
    bool json = true,
    String? idempotencyKey,
  }) async {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    final access = await _tokenStore.readAccess();
    if (access != null && access.isNotEmpty) {
      headers['Authorization'] = 'Bearer $access';
    }
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Future<Result<http.Response>> get(String path, {bool auth = true}) {
    return _send(() async {
      final headers = await _headers();
      if (!auth) {
        headers.remove('Authorization');
      }
      return _http.get(resolve(path), headers: headers);
    }, path: path);
  }

  Future<Result<http.Response>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    String? idempotencyKey,
  }) {
    return _send(() async {
      final headers = await _headers(idempotencyKey: idempotencyKey);
      if (!auth) {
        headers.remove('Authorization');
      }
      return _http.post(
        resolve(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    }, path: path);
  }

  Future<Result<http.Response>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<int> fileBytes,
    required String fileName,
    String contentType = 'application/octet-stream',
    bool auth = true,
    String? idempotencyKey,
  }) {
    return _send(() async {
      final headers = await _headers(
        json: false,
        idempotencyKey: idempotencyKey,
      );
      if (!auth) {
        headers.remove('Authorization');
      }
      final request = http.MultipartRequest('POST', resolve(path));
      request.headers.addAll(headers);
      request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      );
      final streamed = await _http.send(request);
      return await http.Response.fromStream(streamed);
    }, path: path);
  }

  Future<Result<http.Response>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    String? idempotencyKey,
  }) {
    return _send(() async {
      final headers = await _headers(idempotencyKey: idempotencyKey);
      if (!auth) {
        headers.remove('Authorization');
      }
      return _http.put(
        resolve(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    }, path: path);
  }

  Future<Result<http.Response>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    String? idempotencyKey,
  }) {
    return _send(() async {
      final headers = await _headers(idempotencyKey: idempotencyKey);
      if (!auth) {
        headers.remove('Authorization');
      }
      return _http.patch(
        resolve(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    }, path: path);
  }

  Future<Result<http.Response>> _send(
    Future<http.Response> Function() request, {
    required String path,
  }) async {
    try {
      var response = await request();
      if (response.statusCode == 401 && !_isAuthBypass(path)) {
        final refreshed = await _refreshAccessToken();
        if (refreshed != null) {
          response = await request();
          if (response.statusCode != 401) {
            return Success(response);
          }
        }
        await _tokenStore.clear();
        await _onSessionExpired?.call();
        return Failure(AuthSessionExpiredException());
      }
      return Success(response);
    } on Object catch (error, stackTrace) {
      return Failure(error, stackTrace);
    }
  }

  Future<String?> _refreshAccessToken() {
    return _refreshInFlight ??= () async {
      try {
        final refresh = await _tokenStore.readRefresh();
        if (refresh == null || refresh.isEmpty) {
          return null;
        }
        final response = await _http.post(
          resolve('token/refresh/'),
          headers: await _headers()
            ..remove('Authorization'),
          body: jsonEncode({'refresh': refresh}),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        final data = jsonDecode(response.body);
        if (data is! Map || data['access'] == null) {
          return null;
        }
        final access = data['access'].toString();
        await _tokenStore.writeAccess(access);
        return access;
      } finally {
        _refreshInFlight = null;
      }
    }();
  }

  void close() => _http.close();
}

class AuthSessionExpiredException implements Exception {
  @override
  String toString() => 'Session expired. Please sign in again.';
}
