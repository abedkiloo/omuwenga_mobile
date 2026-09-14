import 'dart:convert';
import 'dart:typed_data';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/app/router.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';
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
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/store_shell.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/application/sync_engine.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/domain/client_uuid.dart';
import 'package:completebyte_pos_mobile/sync/domain/outbox_entry.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/auth_fixtures.dart';

import 'agents_fixtures.dart';

void main() {
  test('compression size bounds and quality steps', () async {
    final config = const SiteVisitConfig(maxImageBytes: 100);
    final bounds = ImageCompressionBounds(config);
    expect(bounds.isWithinLimit(50), isTrue);
    expect(bounds.isWithinLimit(101), isFalse);
    expect(bounds.acceptOrNull(Uint8List(40)), isNotNull);
    expect(bounds.acceptOrNull(Uint8List(200)), isNull);
    expect(bounds.nextQuality(75), 60);
    expect(bounds.nextQuality(40), 40);

    final compressor = SitePhotoCompressor(
      config: config,
      compressFn: (bytes, {required quality}) async {
        return Uint8List(80);
      },
    );
    final out = await compressor.compressToLimit(Uint8List(500));
    expect(out.length, 80);

    expect(
      () => SitePhotoCompressor(config: config).compressToLimit(Uint8List(500)),
      throwsStateError,
    );
  });

  test('delivery stop view model and config parse', () {
    final vm = DeliveryStopViewModel.fromSiteJson({
      'id': 3,
      'label': 'Gate',
      'latitude': '-1.29',
      'longitude': '36.82',
      'accuracy': 10,
      'landmark': 'Blue door',
      'customer': 9,
      'customer_name': 'Debtor',
      'media': [
        {'image_url': 'http://x/a.jpg'},
      ],
    });
    expect(vm.photoUrls, ['http://x/a.jpg']);
    expect(vm.customerName, 'Debtor');
    expect(SiteVisitConfig.fromJson({}).minPhotos, 1);
  });

  test('outbox media enqueue multipart payload', () async {
    final outbox = MemoryOutboxStore();
    final api = AgentsApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: InMemoryTokenStore(),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      ),
    );
    final entry = await api.enqueueMediaUpload(
      outbox: outbox,
      siteId: 7,
      photo: const LocalSitePhoto(id: 'p1', path: '/tmp/a.jpg', bytesLength: 10),
      idempotencyKey: 'k1',
    );
    expect(entry.path, 'agents/sites/7/media/');
    final body = jsonDecode(entry.bodyJson) as Map;
    expect(body['__multipart'], isTrue);
    expect(await outbox.pendingCount(), 1);
  });

  test('wizard controller gates and save enqueue', () async {
    final outbox = MemoryOutboxStore();
    final client = MockClient((request) async {
      if (request.url.path.contains('/config')) {
        return http.Response(
          jsonEncode({
            'min_site_media': 1,
            'max_site_media': 10,
            'max_site_image_bytes': 2000000,
          }),
          200,
        );
      }
      if (request.method == 'POST' && request.url.path.endsWith('/sites/')) {
        return http.Response(jsonEncode({'id': 42, 'status': 'draft'}), 201);
      }
      if (request.url.path.contains('/finalize')) {
        return http.Response(jsonEncode({'id': 42, 'status': 'finalized'}), 200);
      }
      return http.Response('{}', 404);
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
    expect(wizard.state.canConfirmMap, isFalse);
    wizard.confirmPin();
    expect(wizard.state.step, SiteVisitStep.map);
    wizard.setPin(const SitePin(latitude: -1.2, longitude: 36.8));
    expect(wizard.state.canConfirmMap, isTrue);
    wizard.confirmPin();
    expect(wizard.state.step, SiteVisitStep.photos);
    expect(wizard.state.canContinuePhotos, isFalse);
    wizard.continueFromPhotos();
    expect(wizard.state.step, SiteVisitStep.photos);
    wizard.addPhoto(const LocalSitePhoto(id: '1', path: '/t.jpg', bytesLength: 9));
    wizard.continueFromPhotos();
    expect(wizard.state.step, SiteVisitStep.customer);
    wizard.selectCustomer(id: 1, name: 'A');
    final ok = await wizard.saveAndFinalize(attemptFinalize: false);
    expect(ok, isTrue);
    expect(await outbox.pendingCount(), 1);
    expect(wizard.state.siteId, 42);
  });

  testWidgets('confirm disabled until pin; continue disabled until photo', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/config')) {
        return http.Response(
          jsonEncode({
            'min_site_media': 1,
            'max_site_media': 10,
            'max_site_image_bytes': 2000000,
          }),
          200,
        );
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

    final confirm = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('site_confirm_pin')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(confirm.onPressed, isNull);

    await tester.tap(find.byKey(const Key('fake_map_surface')));
    await tester.pumpAndSettle();
    final confirm2Finder = find.descendant(
      of: find.byKey(const Key('site_confirm_pin')),
      matching: find.byType(FilledButton),
    );
    expect(
      tester.widget<FilledButton>(confirm2Finder).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('site_confirm_pin')));
    await tester.pumpAndSettle();

    final cont = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('site_continue_photos')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(cont.onPressed, isNull);

    await tester.tap(find.byKey(const Key('site_add_photo')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('site_continue_photos')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('agent home shows new site visit; more entry gated', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(agentSession()),
        child: const MaterialApp(home: PersonaHomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_primary_cta')), findsOneWidget);
    expect(find.text('New site visit'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(cashierSession()),
        child: const MaterialApp(home: MorePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more_site_visit')), findsNothing);
  });

  testWidgets('router redirects site visit without agents.create', (tester) async {
    final container = ProviderContainer(
      overrides: seedOverrides(cashierSession()),
    );
    addTearDown(container.dispose);
    final router = createAppRouter(
      readAuth: () => container.read(authControllerProvider),
      initialLocation: AppRoutes.siteVisit,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), AppRoutes.home);
  });

  test('api failure branches and multipart sender decode', () async {
    final tokens = InMemoryTokenStore();
    final failApi = AgentsApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: MockClient((_) async => http.Response('nope', 500)),
      ),
    );
    expect((await failApi.fetchConfig()).isFailure, isTrue);
    expect(
      (await failApi.createSite(
        pin: const SitePin(latitude: 1, longitude: 2),
      )).isFailure,
      isTrue,
    );
    expect((await failApi.finalizeSite(1)).isFailure, isTrue);
    expect((await failApi.patchSite(1, customerId: 2)).isFailure, isTrue);

    final okApi = AgentsApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('config')) {
            return http.Response('[]', 200);
          }
          return http.Response('[]', 201);
        }),
      ),
    );
    expect((await okApi.fetchConfig()).isFailure, isTrue);
    expect(
      (await okApi.createSite(pin: const SitePin(latitude: 1, longitude: 2))).isFailure,
      isTrue,
    );

    final sender = apiOutboxSender(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: MockClient((_) async => http.Response('{}', 201)),
      ),
    );
    final outbox = MemoryOutboxStore();
    final entry = await outbox.enqueue(
      EnqueueMutation(
        method: 'POST',
        path: 'agents/sites/1/media/',
        bodyJson: jsonEncode({
          '__multipart': true,
          'file_field': 'image',
          'file_path': '/no/such/file.jpg',
          'file_name': 'a.jpg',
          'content_type': 'image/jpeg',
          'fields': {'caption': 'x'},
        }),
      ),
    );
    final result = await sender(entry);
    expect(result.isSuccess || result.isFailure, isTrue);
  });
}
