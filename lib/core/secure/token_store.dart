/// Secure token persistence. Never log token values.
abstract class TokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> writeTokens({required String access, required String refresh});
  Future<void> writeAccess(String access);
  Future<void> clear();
}

/// In-memory store for tests and widget harnesses.
class InMemoryTokenStore implements TokenStore {
  String? _access;
  String? _refresh;

  @override
  Future<String?> readAccess() async => _access;

  @override
  Future<String?> readRefresh() async => _refresh;

  @override
  Future<void> writeTokens({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> writeAccess(String access) async {
    _access = access;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
