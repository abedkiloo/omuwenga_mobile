import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../../core/secure/token_store.dart';
import '../data/auth_api.dart';
import '../domain/auth_session.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Test-only seed — when non-null, [AuthController] starts authenticated.
final authSessionSeedProvider = Provider<AuthSession?>((ref) => null);

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.message,
    this.busy = false,
  });

  final AuthStatus status;
  final AuthSession? session;
  final String? message;
  final bool busy;

  bool get isAuthenticated => status == AuthStatus.authenticated && session != null;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? message,
    bool clearMessage = false,
    bool? busy,
    bool clearSession = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      message: clearMessage ? null : (message ?? this.message),
      busy: busy ?? this.busy,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  AuthApi get _api => ref.read(authApiProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  AuthState build() {
    // Watch so auth client/token wiring invalidates cleanly.
    ref.watch(authApiProvider);
    ref.watch(tokenStoreProvider);
    final seed = ref.watch(authSessionSeedProvider);
    if (seed != null) {
      return AuthState(status: AuthStatus.authenticated, session: seed);
    }
    return const AuthState(status: AuthStatus.unknown);
  }

  Future<void> bootstrap() async {
    final access = await _tokens.readAccess();
    final refresh = await _tokens.readRefresh();
    if ((access == null || access.isEmpty) && (refresh == null || refresh.isEmpty)) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    final result = await _api.me();
    state = result.when(
      success: (session) => AuthState(status: AuthStatus.authenticated, session: session),
      failure: (error, _) => AuthState(
        status: AuthStatus.unauthenticated,
        message: error is AuthFailure ? error.message : AuthFailure.sessionExpired().message,
      ),
    );
    if (!state.isAuthenticated) {
      await _tokens.clear();
    }
  }

  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    final trimmedUser = username.trim();
    if (trimmedUser.isEmpty || password.isEmpty) {
      final failure = AuthFailure.server('Enter your username and password.');
      state = state.copyWith(message: failure.message, busy: false);
      return Failure(failure);
    }
    state = state.copyWith(busy: true, clearMessage: true);
    final result = await _api.login(username: trimmedUser, password: password);
    state = result.when(
      success: (session) => AuthState(
        status: AuthStatus.authenticated,
        session: session,
        busy: false,
      ),
      failure: (error, _) => AuthState(
        status: AuthStatus.unauthenticated,
        busy: false,
        message: error is AuthFailure
            ? error.message
            : 'Could not sign in. Check your connection and try again.',
      ),
    );
    return result;
  }

  Future<void> logout() async {
    state = state.copyWith(busy: true);
    await _api.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void markSessionExpired() {
    state = AuthState(
      status: AuthStatus.unauthenticated,
      message: AuthFailure.sessionExpired().message,
    );
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Bridges [authControllerProvider] to GoRouter refresh.
class AuthRouterListenable extends ChangeNotifier {
  AuthRouterListenable(dynamic ref) {
    // Accepts both [Ref] and [WidgetRef].
    // ignore: avoid_dynamic_calls
    ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }
}
