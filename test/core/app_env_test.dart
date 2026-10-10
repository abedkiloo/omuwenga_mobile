import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnv', () {
    test('parseFlavor maps aliases', () {
      expect(AppEnv.parseFlavor('dev'), AppFlavor.dev);
      expect(AppEnv.parseFlavor('development'), AppFlavor.dev);
      expect(AppEnv.parseFlavor('staging'), AppFlavor.staging);
      expect(AppEnv.parseFlavor('uat'), AppFlavor.staging);
      expect(AppEnv.parseFlavor('prod'), AppFlavor.prod);
      expect(AppEnv.parseFlavor('production'), AppFlavor.prod);
      expect(AppEnv.parseFlavor('unknown'), AppFlavor.dev);
    });

    test('resolveFlavor uses build mode when APP_ENV is omitted', () {
      expect(
        AppEnv.resolveFlavor('', releaseMode: false),
        AppFlavor.dev,
      );
      expect(
        AppEnv.resolveFlavor('', releaseMode: true),
        AppFlavor.prod,
      );
      expect(
        AppEnv.resolveFlavor('uat', releaseMode: true),
        AppFlavor.staging,
      );
      expect(
        AppEnv.resolveFlavor('prod', releaseMode: false),
        AppFlavor.prod,
      );
    });

    test('defaultBaseUrl uses UAT API for debug/staging and shop for prod', () {
      const uat = 'https://api.uat.omuwenga.com/api';
      const shop = 'https://shop.omuwenga.com/api';
      expect(AppEnv.defaultBaseUrl(AppFlavor.dev), uat);
      expect(AppEnv.defaultBaseUrl(AppFlavor.staging), uat);
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
      expect(env.isProd, isFalse);
    });

    test('fromDefines falls back to flavor default when override empty', () {
      final env = AppEnv.fromDefines(flavorName: 'dev', apiBaseUrlOverride: '');
      expect(env.apiBaseUrl, AppEnv.defaultBaseUrl(AppFlavor.dev));
      expect(env.isDev, isTrue);
    });

    test('fromDefines without APP_ENV follows releaseMode', () {
      final debugEnv = AppEnv.fromDefines(
        flavorName: '',
        apiBaseUrlOverride: '',
        releaseMode: false,
      );
      expect(debugEnv.flavor, AppFlavor.dev);
      expect(debugEnv.isNonProd, isTrue);
      expect(debugEnv.environmentLabel, 'UAT');
      expect(debugEnv.apiBaseUrl, 'https://api.uat.omuwenga.com/api');

      final releaseEnv = AppEnv.fromDefines(
        flavorName: '',
        apiBaseUrlOverride: '',
        releaseMode: true,
      );
      expect(releaseEnv.flavor, AppFlavor.prod);
      expect(releaseEnv.isProd, isTrue);
      expect(releaseEnv.environmentLabel, '');
      expect(releaseEnv.apiBaseUrl, 'https://shop.omuwenga.com/api');
    });
  });
}
