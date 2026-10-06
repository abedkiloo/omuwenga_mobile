import 'package:flutter/foundation.dart';

/// Environment / flavor configuration via `--dart-define`.
///
/// When `APP_ENV` is omitted:
/// - **debug / profile** → UAT (`AppFlavor.dev`)
/// - **release** → production (`AppFlavor.prod`)
enum AppFlavor { dev, staging, prod }

class AppEnv {
  const AppEnv({required this.flavor, required this.apiBaseUrl});

  final AppFlavor flavor;
  final String apiBaseUrl;

  /// Reads compile-time defines. Build mode picks UAT vs prod when `APP_ENV` is unset.
  factory AppEnv.fromDefines({
    String flavorName = const String.fromEnvironment('APP_ENV'),
    String apiBaseUrlOverride = const String.fromEnvironment('API_BASE_URL'),
    bool? releaseMode,
  }) {
    final flavor = resolveFlavor(
      flavorName,
      releaseMode: releaseMode ?? kReleaseMode,
    );
    final url = apiBaseUrlOverride.trim().isNotEmpty
        ? _normalizeBase(apiBaseUrlOverride)
        : defaultBaseUrl(flavor);
    return AppEnv(flavor: flavor, apiBaseUrl: url);
  }

  /// Explicit `APP_ENV` wins; otherwise release → prod, debug/profile → UAT.
  static AppFlavor resolveFlavor(String raw, {required bool releaseMode}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return releaseMode ? AppFlavor.prod : AppFlavor.dev;
    }
    return parseFlavor(trimmed);
  }

  static AppFlavor parseFlavor(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'staging':
      case 'uat':
        return AppFlavor.staging;
      case 'prod':
      case 'production':
        return AppFlavor.prod;
      case 'dev':
      case 'development':
      default:
        return AppFlavor.dev;
    }
  }

  static String defaultBaseUrl(AppFlavor flavor) {
    const uatApi = 'https://api.uat.omuwenga.com/api';
    const shopApi = 'https://shop.omuwenga.com/api';
    switch (flavor) {
      case AppFlavor.dev:
      case AppFlavor.staging:
        return uatApi;
      case AppFlavor.prod:
        return shopApi;
    }
  }

  static String _normalizeBase(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  bool get isDev => flavor == AppFlavor.dev;
  bool get isProd => flavor == AppFlavor.prod;
}
