import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/payments/application/payment_controllers.dart';
import 'package:completebyte_pos_mobile/features/payments/data/payments_api.dart';
import 'package:completebyte_pos_mobile/features/payments/domain/payment_intent.dart';
import 'package:completebyte_pos_mobile/features/payments/presentation/stk_wait_page.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> intentJson({
  int id = 1,
  String status = 'created',
  String amount = '100.00',
  String phone = '0712345678',
  String purpose = 'pos',
  bool smsSent = false,
  String? receipt,
  String? failure,
}) {
  return {
    'id': id,
    'amount': amount,
    'phone': phone,
    'status': status,
    'purpose': purpose,
    'invoice_number': 'INV-$id',
    'invoice_link_token': 'tok-$id',
    'mpesa_receipt': receipt,
    'failure_reason': failure,
    'sms_queued': smsSent,
    'sms_sent': smsSent,
    'customer_name': 'Ann',
  };
}

void main() {
  late InMemoryTokenStore tokens;

  setUp(() async {
    tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
  });

  ApiClient clientWith(MockClient httpClient) {
    return ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: httpClient,
    );
  }

  PaymentsApi apiWith(MockClient httpClient) =>
      PaymentsApi(clientWith(httpClient));

  group('PaymentIntent domain', () {
    test('parses statuses and flags', () {
      expect(
        PaymentIntentStatus.parse('prompted'),
        PaymentIntentStatus.prompted,
      );
      expect(PaymentIntentStatus.parse('PAID'), PaymentIntentStatus.paid);
      expect(PaymentIntentStatus.parse('failed'), PaymentIntentStatus.failed);
      expect(
        PaymentIntentStatus.parse('cancelled'),
        PaymentIntentStatus.cancelled,
      );
      expect(PaymentIntentStatus.parse('expired'), PaymentIntentStatus.expired);
      expect(PaymentIntentStatus.parse(null), PaymentIntentStatus.created);
      expect(PaymentIntentStatus.paid.isTerminal, isTrue);
      expect(PaymentIntentStatus.prompted.isWaiting, isTrue);

      final intent = PaymentIntent.fromJson(
        intentJson(
          status: 'paid',
          purpose: 'debt',
          smsSent: true,
          receipt: 'QHX',
        ),
      );
      expect(intent.purpose, PaymentPurpose.debt);
      expect(intent.smsSent, isTrue);
      expect(intent.mpesaReceipt, 'QHX');
      expect(
        PaymentIntent.fromJson(intentJson(purpose: 'unknown')).purpose,
        PaymentPurpose.other,
      );
    });
  });

  group('PaymentsApi', () {
    test('create sendStk get query success paths', () async {
      Map<String, dynamic>? createBody;
      final api = apiWith(
        MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/payments/intents/') && request.method == 'POST') {
            createBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(intentJson(status: 'created')),
              201,
            );
          }
          if (path.contains('/stk/')) {
            return http.Response(
              jsonEncode(intentJson(status: 'prompted')),
              200,
            );
          }
          if (path.contains('/query/')) {
            return http.Response(
              jsonEncode(
                intentJson(status: 'paid', smsSent: true, receipt: 'R1'),
              ),
              200,
            );
          }
          if (path.contains('/intents/1/')) {
            return http.Response(
              jsonEncode(intentJson(status: 'prompted')),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      expect(
        (await api.create(
          amount: 100,
          phone: '0712',
          purpose: 'pos',
          customerId: 9,
          customerName: 'Ann',
          clientUuid: 'uuid-1',
        )).getOrThrow().status,
        PaymentIntentStatus.created,
      );
      expect(createBody?['customer_id'], 9);
      expect(createBody?['customer_name'], 'Ann');
      expect(createBody?['client_uuid'], 'uuid-1');
      expect(
        (await api.sendStk(1)).getOrThrow().status,
        PaymentIntentStatus.prompted,
      );
      expect(
        (await api.get(1)).getOrThrow().status,
        PaymentIntentStatus.prompted,
      );
      final paid = (await api.query(1)).getOrThrow();
      expect(paid.status, PaymentIntentStatus.paid);
      expect(paid.smsSent, isTrue);
    });

    test('maps http and decode failures', () async {
      final badStatus = apiWith(
        MockClient((_) async => http.Response('nope', 500)),
      );
      expect(
        (await badStatus.create(
          amount: 1,
          phone: '1',
          purpose: 'pos',
        )).isFailure,
        isTrue,
      );

      final badJson = apiWith(
        MockClient((_) async => http.Response('not-json', 200)),
      );
      expect((await badJson.get(1)).isFailure, isTrue);

      final notMap = apiWith(
        MockClient((_) async => http.Response(jsonEncode([1]), 200)),
      );
      expect((await notMap.get(1)).isFailure, isTrue);

      expect(PaymentsApiException('x').toString(), 'x');
    });

    test('propagates transport failure', () async {
      final api = apiWith(MockClient((_) async => throw Exception('down')));
      expect((await api.sendStk(1)).isFailure, isTrue);
    });
  });

  group('StkWaitController', () {
    test('blocks offline and starts polling online', () async {
      final offline = StkWaitController(
        apiWith(MockClient((_) async => http.Response('{}', 200))),
        FakeConnectivityMonitor(online: false),
      );
      expect(
        await offline.start(amount: 10, phone: '0700', purpose: 'pos'),
        isFalse,
      );
      expect(offline.state.offlineBlocked, isTrue);
      offline.dispose();

      var polls = 0;
      final onlineApi = apiWith(
        MockClient((request) async {
          if (request.url.path.endsWith('/payments/intents/')) {
            return http.Response(jsonEncode(intentJson()), 201);
          }
          if (request.url.path.contains('/stk/')) {
            return http.Response(
              jsonEncode(intentJson(status: 'prompted')),
              200,
            );
          }
          polls++;
          return http.Response(
            jsonEncode(
              intentJson(
                status: polls >= 1 ? 'paid' : 'prompted',
                smsSent: true,
              ),
            ),
            200,
          );
        }),
      );
      final online = StkWaitController(onlineApi, FakeConnectivityMonitor());
      expect(
        await online.start(amount: 10, phone: '0700', purpose: 'pos'),
        isTrue,
      );
      expect(online.state.intent?.status, PaymentIntentStatus.prompted);
      await online.refresh(1);
      expect(online.state.isPaid, isTrue);
      expect(online.state.showSmsSent, isTrue);
      await online.queryNow();
      online.reset();
      expect(online.state.intent, isNull);
      online.dispose();
    });

    test('create and stk failures surface errors', () async {
      final createFail = StkWaitController(
        apiWith(MockClient((_) async => http.Response('x', 400))),
        FakeConnectivityMonitor(),
      );
      expect(
        await createFail.start(amount: 1, phone: '1', purpose: 'pos'),
        isFalse,
      );
      expect(createFail.state.error, isNotNull);
      createFail.dispose();

      var n = 0;
      final stkFail = StkWaitController(
        apiWith(
          MockClient((request) async {
            n++;
            if (n == 1) {
              return http.Response(jsonEncode(intentJson()), 201);
            }
            return http.Response('stk down', 502);
          }),
        ),
        FakeConnectivityMonitor(),
      );
      expect(
        await stkFail.start(amount: 1, phone: '1', purpose: 'pos'),
        isFalse,
      );
      expect(stkFail.state.intent, isNotNull);
      expect(stkFail.state.error, isNotNull);
      stkFail.dispose();
    });

    test('queryNow failure keeps error', () async {
      final c = StkWaitController(
        apiWith(
          MockClient((request) async {
            if (request.url.path.endsWith('/payments/intents/')) {
              return http.Response(jsonEncode(intentJson()), 201);
            }
            if (request.url.path.contains('/stk/')) {
              return http.Response(
                jsonEncode(intentJson(status: 'prompted')),
                200,
              );
            }
            return http.Response('bad', 500);
          }),
        ),
        FakeConnectivityMonitor(),
      );
      await c.start(amount: 1, phone: '1', purpose: 'pos');
      await c.queryNow();
      expect(c.state.error, isNotNull);
      c.dispose();
    });
  });

  group('StkWaitPage widgets', () {
    Widget harness({required MockClient httpClient, bool online = true}) {
      return ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(clientWith(httpClient)),
          connectivityMonitorProvider.overrideWithValue(
            FakeConnectivityMonitor(online: online),
          ),
        ],
        child: const MaterialApp(
          home: StkWaitPage(
            amount: 250,
            phone: '0712345678',
            purpose: 'pos',
            customerName: 'Ann',
          ),
        ),
      );
    }

    testWidgets('offline blocked state', (tester) async {
      await tester.pumpWidget(
        harness(
          httpClient: MockClient((_) async => http.Response('{}', 200)),
          online: false,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('stk_title')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('stk_title'))).data,
        'Offline',
      );
    });

    testWidgets('shows non-offline error from failed create', (tester) async {
      await tester.pumpWidget(
        harness(
          httpClient: MockClient((_) async => http.Response('denied', 403)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('stk_error')), findsOneWidget);
    });

    testWidgets('waiting then success with SMS', (tester) async {
      await tester.pumpWidget(
        harness(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/payments/intents/')) {
              return http.Response(jsonEncode(intentJson()), 201);
            }
            if (request.url.path.contains('/stk/')) {
              return http.Response(
                jsonEncode(intentJson(status: 'prompted')),
                200,
              );
            }
            if (request.url.path.contains('/query/')) {
              return http.Response(
                jsonEncode(
                  intentJson(status: 'paid', smsSent: true, receipt: 'QHX99'),
                ),
                200,
              );
            }
            return http.Response(
              jsonEncode(intentJson(status: 'prompted')),
              200,
            );
          }),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.widget<Text>(find.byKey(const Key('stk_title'))).data,
        'Waiting for M-Pesa',
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('stk_query')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.widget<Text>(find.byKey(const Key('stk_title'))).data,
        'Payment confirmed',
      );
      expect(find.byKey(const Key('stk_sms_sent')), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('failed payment body', (tester) async {
      await tester.pumpWidget(
        harness(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/payments/intents/')) {
              return http.Response(jsonEncode(intentJson()), 201);
            }
            if (request.url.path.contains('/stk/')) {
              return http.Response(
                jsonEncode(intentJson(status: 'prompted')),
                200,
              );
            }
            return http.Response(
              jsonEncode(
                intentJson(status: 'failed', failure: 'Customer cancelled'),
              ),
              200,
            );
          }),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('stk_query')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.widget<Text>(find.byKey(const Key('stk_title'))).data,
        'Payment not completed',
      );
      expect(find.text('Customer cancelled'), findsOneWidget);
    });

    testWidgets('showStkWaitSheet pops paid intent', (tester) async {
      PaymentIntent? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(
              clientWith(
                MockClient((request) async {
                  if (request.url.path.endsWith('/payments/intents/')) {
                    return http.Response(jsonEncode(intentJson()), 201);
                  }
                  if (request.url.path.contains('/stk/')) {
                    return http.Response(
                      jsonEncode(intentJson(status: 'prompted')),
                      200,
                    );
                  }
                  if (request.url.path.contains('/query/')) {
                    return http.Response(
                      jsonEncode(intentJson(status: 'paid', receipt: 'R2')),
                      200,
                    );
                  }
                  return http.Response(
                    jsonEncode(intentJson(status: 'prompted')),
                    200,
                  );
                }),
              ),
            ),
            connectivityMonitorProvider.overrideWithValue(
              FakeConnectivityMonitor(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: const Key('open_stk'),
                  onPressed: () async {
                    result = await showStkWaitSheet(
                      context,
                      amount: 50,
                      phone: '0700',
                      purpose: 'debt',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open_stk')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('stk_query')), findsOneWidget);
      await tester.tap(find.byKey(const Key('stk_query')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('stk_done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(result?.status, PaymentIntentStatus.paid);
      expect(result?.mpesaReceipt, 'R2');
    });
  });
}
