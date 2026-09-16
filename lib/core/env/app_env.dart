/// Environment / flavor configuration via `--dart-define`.
enum AppFlavor { dev, staging, prod }

class AppEnv {
  const AppEnv({required this.flavor, required this.apiBaseUrl});

  final AppFlavor flavor;
  final String apiBaseUrl;

  /// Reads compile-time defines. Defaults to [AppFlavor.dev].
  factory AppEnv.fromDefines({
    String flavorName = const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'dev',
    ),
    String? apiBaseUrlOverride = const String.fromEnvironment('API_BASE_URL'),
  }) {
    final flavor = parseFlavor(flavorName);
    final url = (apiBaseUrlOverride != null && apiBaseUrlOverride.isNotEmpty)
        ? _normalizeBase(apiBaseUrlOverride)
        : defaultBaseUrl(flavor);
    return AppEnv(flavor: flavor, apiBaseUrl: url);
  }

  static AppFlavor parseFlavor(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'staging':
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
    // Production shop https://shop.omuwenga.com/ — DRF API under /api.
    const shopApi = 'https://shop.omuwenga.com/api';
    switch (flavor) {
      case AppFlavor.dev:
      case AppFlavor.staging:
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
}
