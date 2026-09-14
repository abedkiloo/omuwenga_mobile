import 'dart:convert';
import 'dart:typed_data';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/agents/application/site_visit_controllers.dart';
import 'package:completebyte_pos_mobile/features/agents/data/agents_api.dart';
import 'package:completebyte_pos_mobile/features/agents/domain/image_compression.dart';
import 'package:completebyte_pos_mobile/features/agents/domain/site_visit.dart';
import 'package:completebyte_pos_mobile/features/agents/presentation/map_pin_picker.dart';
import 'package:completebyte_pos_mobile/features/agents/presentation/site_visit_wizard_page.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/domain/client_uuid.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'agents_fixtures.dart';

void main() {
  test('pin copyWith and compressor exhaust retries', () async {
    final pin = const SitePin(latitude: 1, longitude: 2, label: 'a')
        .copyWith(latitude: 3, longitude: 4, accuracy: 1, label: 'b');
    expect(pin.latitude, 3);
    expect(pin.label, 'b');

    final compressor = SitePhotoCompressor(
      config: const SiteVisitConfig(maxImageBytes: 10, compressQuality: 75),
      compressFn: (bytes, {required quality}) async => Uint8List(100),
    );
    expect(
      () => compressor.compressToLimit(Uint8List(50)),
      throwsStateError,
    );
  });

  test('agents api success paths and exception toString', () async {
    expect(AgentsApiException('x').toString(), 'x');
    final tokens = InMemoryTokenStore();
    final client = MockClient((request) async {
      if (request.url.path.contains('config')) {
        return http.Response(
          jsonEncode({
            'min_site_media': 1,
            'max_site_media': 5,
            'max_site_image_bytes': 1000,
          }),
          200,
        );
      }
      if (request.url.path.contains('finalize')) {
        return http.Response(jsonEncode({'id': 1, 'status': 'finalized'}), 200);
      }
      if (request.method == 'PATCH') {
        return http.Response(jsonEncode({'id': 1, 'landmark': 'L'}), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/sites/')) {
        return http.Response(jsonEncode({'id': 1, 'status': 'draft'}), 201);
      }
      return http.Response(jsonEncode({'id': 1}), 200);
    });
    final api = AgentsApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: client,
      ),
    );
    expect((await api.fetchConfig()).isSuccess, isTrue);
    expect(
      (await api.createSite(
        pin: const SitePin(latitude: 1, longitude: 2, accuracy: 3),
        customerId: 9,
      )).isSuccess,
      isTrue,
    );
    expect((await api.patchSite(1, landmark: 'L', label: 'G')).isSuccess, isTrue);
    expect((await api.finalizeSite(1)).isSuccess, isTrue);
  });

  test('wizard remove photo goToStep finalize fail and success', () async {
    final outbox = MemoryOutboxStore();
    var finalizeOk = false;
    final client = MockClient((request) async {
      if (request.url.path.contains('config')) {
        return http.Response(jsonEncode({'min_site_media': 1}), 200);
      }
      if (request.url.path.endsWith('/sites/') && request.method == 'POST') {
        return http.Response(jsonEncode({'id': 5}), 201);
      }
      if (request.url.path.contains('finalize')) {
        if (!finalizeOk) return http.Response('nope', 400);
        return http.Response(jsonEncode({'id': 5, 'status': 'finalized'}), 200);
      }
      return http.Response('{}', 500);
    });
    final api = AgentsApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: InMemoryTokenStore(),
        httpClient: client,
      ),
    );
    final wizard = SiteVisitWizardController(api, outbox, ids: ClientUuid());
    await wizard.loadConfig();
    wizard.goToStep(SiteVisitStep.photos);
    expect(wizard.state.step, SiteVisitStep.map);
    wizard.setPin(const SitePin(latitude: 1, longitude: 2));
    wizard.setLandmark('near');
    wizard.confirmPin();
    wizard.addPhoto(const LocalSitePhoto(id: 'a', path: '/a.jpg', bytesLength: 1));
    wizard.addPhoto(const LocalSitePhoto(id: 'b', path: '/b.jpg', bytesLength: 1));
    wizard.removePhoto('a');
    expect(wizard.state.photos.length, 1);
    wizard.goToStep(SiteVisitStep.customer);
    wizard.selectCustomer(id: 3, name: 'C');
    expect(await wizard.saveAndFinalize(), isFalse);
    expect(wizard.state.error, isNotNull);

    finalizeOk = true;
    final wizard2 = SiteVisitWizardController(api, outbox, ids: ClientUuid());
    wizard2.setPin(const SitePin(latitude: 1, longitude: 2));
    wizard2.confirmPin();
    wizard2.addPhoto(const LocalSitePhoto(id: 'c', path: '/c.jpg', bytesLength: 1));
    wizard2.continueFromPhotos();
    wizard2.selectCustomer(id: 3, name: 'C');
    expect(await wizard2.saveAndFinalize(), isTrue);
    expect(wizard2.state.finalized, isTrue);

    // create failure
    final failApi = AgentsApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: InMemoryTokenStore(),
        httpClient: MockClient((_) async => http.Response('x', 500)),
      ),
    );
    final w3 = SiteVisitWizardController(failApi, outbox);
    w3.setPin(const SitePin(latitude: 1, longitude: 2));
    w3.confirmPin();
    w3.addPhoto(const LocalSitePhoto(id: 'd', path: '/d.jpg', bytesLength: 1));
    w3.continueFromPhotos();
    w3.selectCustomer(id: 1, name: 'n');
    expect(await w3.saveAndFinalize(), isFalse);
  });

  testWidgets('full wizard save CTA path', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('config')) {
        return http.Response(jsonEncode({'min_site_media': 1}), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/sites/')) {
        return http.Response(jsonEncode({'id': 9}), 201);
      }
      if (request.url.path.contains('finalize')) {
        return http.Response(jsonEncode({'id': 9, 'status': 'finalized'}), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: agentOverrides(client),
        child: MaterialApp(
          home: SiteVisitWizardPage(mapPickerBuilder: fakeMapPinPickerBuilder),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake_map_surface')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('site_landmark')), 'Blue gate');
    await tester.tap(find.byKey(const Key('site_confirm_pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site_add_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site_continue_photos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site_pick_customer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('site_customer_label')), findsOneWidget);
    await tester.tap(find.byKey(const Key('site_save_finalize')));
    await tester.pumpAndSettle();
  });


  test('site pin label empty and delivery media skip non maps', () {
    expect(const SitePin(latitude: 1, longitude: 2).copyWith().longitude, 2);
    final vm = DeliveryStopViewModel.fromSiteJson({
      'id': 1,
      'label': '',
      'latitude': 1,
      'longitude': 2,
      'media': ['skip', {'image_url': null}, {'no': 1}],
    });
    expect(vm.photoUrls, isEmpty);
  });

  test('agents api invalid json bodies', () async {
    final api = AgentsApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: InMemoryTokenStore(),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('config')) return http.Response('null', 200);
          if (request.url.path.contains('finalize')) return http.Response('null', 200);
          if (request.method == 'PATCH') return http.Response('null', 200);
          return http.Response('null', 201);
        }),
      ),
    );
    expect((await api.fetchConfig()).isFailure, isTrue);
    expect((await api.createSite(pin: const SitePin(latitude: 1, longitude: 2))).isFailure, isTrue);
    expect((await api.patchSite(1)).isFailure, isTrue);
    expect((await api.finalizeSite(1)).isFailure, isTrue);
  });

  testWidgets('default map picker builder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => defaultMapPinPickerBuilder(
            context,
            selected: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('fake_map_surface')), findsOneWidget);
  });

  test('api decode throws and max photos gate', () async {
    final api = AgentsApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: InMemoryTokenStore(),
        httpClient: MockClient((_) async => http.Response('{', 200)),
      ),
    );
    expect((await api.fetchConfig()).isFailure, isTrue);
    expect((await api.createSite(pin: const SitePin(latitude: 1, longitude: 2))).isFailure, isTrue);
    expect((await api.patchSite(1, customerId: 1)).isFailure, isTrue);
    expect((await api.finalizeSite(1)).isFailure, isTrue);

    final outbox = MemoryOutboxStore();
    final wizard = SiteVisitWizardController(
      AgentsApi(
        ApiClient(
          env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
          tokenStore: InMemoryTokenStore(),
          httpClient: MockClient((_) async => http.Response(jsonEncode({'min_site_media': 1, 'max_site_media': 1}), 200)),
        ),
      ),
      outbox,
    );
    await wizard.loadConfig();
    expect(wizard.state.config.maxPhotos, 1);
    wizard.addPhoto(const LocalSitePhoto(id: '1', path: '/a', bytesLength: 1));
    wizard.addPhoto(const LocalSitePhoto(id: '2', path: '/b', bytesLength: 1));
    expect(wizard.state.photos.length, 1);
    await wizard.loadConfig(); // failure path ignored when body bad — use failing client below
  });

  testWidgets('photo delete chip and error banner', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('config')) {
        return http.Response(jsonEncode({'min_site_media': 1}), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/sites/')) {
        return http.Response('x', 500);
      }
      return http.Response('{}', 200);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: agentOverrides(client),
        child: MaterialApp(
          home: SiteVisitWizardPage(mapPickerBuilder: fakeMapPinPickerBuilder),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake_map_surface')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site_confirm_pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site_add_photo')));
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsOneWidget);
    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site_add_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site_continue_photos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site_pick_customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site_save_finalize')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('site_visit_error')), findsOneWidget);
  });
}
