import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnv', () {
    test('parseFlavor maps aliases', () {
      expect(AppEnv.parseFlavor('dev'), AppFlavor.dev);
      expect(AppEnv.parseFlavor('development'), AppFlavor.dev);
      expect(AppEnv.parseFlavor('staging'), AppFlavor.staging);
      expect(AppEnv.parseFlavor('prod'), AppFlavor.prod);
      expect(AppEnv.parseFlavor('production'), AppFlavor.prod);
      expect(AppEnv.parseFlavor('unknown'), AppFlavor.dev);
    });

    test('defaultBaseUrl points at shop.omuwenga.com', () {
      const shop = 'https://shop.omuwenga.com/api';
      expect(AppEnv.defaultBaseUrl(AppFlavor.dev), shop);
      expect(AppEnv.defaultBaseUrl(AppFlavor.staging), shop);
      expect(AppEnv.defaultBaseUrl(AppFlavor.prod), shop);
    });

    test('fromDefines uses override and strips trailing slash', () {
      final env = AppEnv.fromDefines(
        flavorName: 'staging',
        apiBaseUrlOverride: 'https://custom.example/api/',
      );
      expect(env.flavor, AppFlavor.staging);
      expect(env.apiBaseUrl, 'https://custom.example/api');
      expect(env.isDev, isFalse);
    });

    test('fromDefines falls back to flavor default when override empty', () {
      final env = AppEnv.fromDefines(flavorName: 'dev', apiBaseUrlOverride: '');
      expect(env.apiBaseUrl, AppEnv.defaultBaseUrl(AppFlavor.dev));
      expect(env.isDev, isTrue);
    });
  });
}
