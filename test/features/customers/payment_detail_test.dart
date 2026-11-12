import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/customers/data/customers_api.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/payment_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PaymentDetail unit', () {
    test('parses till/bank payer and paid_towards', () {
      final detail = PaymentDetail.fromJson({
        'id': 12,
        'kind': 'debt_settlement',
        'amount': '80.50',
        'customer_id': 3,
        'customer_name': 'Ada',
        'payment_method': 'mpesa',
        'payment_method_label': 'M-PESA',
        'mpesa_destination': 'till',
        'mpesa_destination_label': 'Till',
        'payer_name': 'Mary',
        'payer_phone': '0700111222',
        'reference': 'QHX7K2L9M1',
        'received_by': 'Cashier',
        'receipt_image_url': '/media/x.jpg',
        'paid_towards_label': 'Customer debt',
        'paid_towards': [
          {
            'type': 'customer_debt',
            'label': 'Customer debt',
            'amount': '80.50',
          },
        ],
        'previous_debt': '100.00',
        'new_debt': '19.50',
      });
      expect(detail.id, 12);
      expect(detail.methodDisplay, 'M-PESA · Till');
      expect(detail.payerDisplay, 'Mary · 0700111222');
      expect(detail.paidTowards, hasLength(1));
      expect(detail.previousDebt, 100);
      expect(detail.newDebt, 19.5);
    });

    test('stress-parses many payment payloads', () {
      for (var i = 0; i < 500; i++) {
        final detail = PaymentDetail.fromJson({
          'id': i,
          'amount': '${i % 50}.00',
          'payment_method': i.isEven ? 'mpesa' : 'cash',
          'payment_method_label': i.isEven ? 'M-PESA' : 'Cash',
          'mpesa_destination': i.isEven ? (i % 4 == 0 ? 'till' : 'bank') : '',
          'payer_name': i % 3 == 0 ? 'P$i' : '',
        });
        expect(detail.id, i);
        expect(detail.methodDisplay, isNotEmpty);
      }
    });
  });

  group('CustomersApi walletSettlementDetail integration', () {
    late InMemoryTokenStore tokens;

    setUp(() async {
      tokens = InMemoryTokenStore();
      await tokens.writeTokens(access: 'a', refresh: 'r');
    });

    CustomersApi apiWith(MockClient client) {
      return CustomersApi(
        ApiClient(
          env: const AppEnv(
            flavor: AppFlavor.dev,
            apiBaseUrl: 'http://example.com/api',
          ),
          tokenStore: tokens,
          httpClient: client,
        ),
      );
    }

    test('GET wallet settlement detail maps JSON', () async {
      final api = apiWith(
        MockClient((request) async {
          expect(request.url.path, endsWith('/wallet-settlements/44/'));
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode({
              'id': 44,
              'kind': 'debt_settlement',
              'amount': '25.00',
              'payer_name': 'Ada',
              'mpesa_destination': 'bank',
              'mpesa_destination_label': 'Bank',
              'payment_method_label': 'M-PESA',
              'receipt_image_url': '/media/r.jpg',
            }),
            200,
          );
        }),
      );
      final detail = (await api.walletSettlementDetail(44)).getOrThrow();
      expect(detail.id, 44);
      expect(detail.methodDisplay, 'M-PESA · Bank');
      expect(detail.receiptImageUrl, '/media/r.jpg');
    });

    test('maps 404 to failure', () async {
      final api = apiWith(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'Settlement not found.'}),
            404,
          ),
        ),
      );
      final result = await api.walletSettlementDetail(999);
      expect(result.isFailure, isTrue);
    });
  });

  group('CustomersApi walletSettlementDetail security', () {
    late InMemoryTokenStore tokens;

    setUp(() async {
      tokens = InMemoryTokenStore();
      await tokens.writeTokens(access: 'a', refresh: 'r');
    });

    CustomersApi apiWith(MockClient client) {
      return CustomersApi(
        ApiClient(
          env: const AppEnv(
            flavor: AppFlavor.dev,
            apiBaseUrl: 'http://example.com/api',
          ),
          tokenStore: tokens,
          httpClient: client,
        ),
      );
    }

    test('maps 401 unauthorized to failure without inventing detail', () async {
      final api = apiWith(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'detail': 'Authentication credentials were not provided.'}),
            401,
          ),
        ),
      );
      final result = await api.walletSettlementDetail(44);
      expect(result.isFailure, isTrue);
    });

    test('maps 403 forbidden IDOR/permission to failure', () async {
      final api = apiWith(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'You cannot view this settlement.'}),
            403,
          ),
        ),
      );
      final result = await api.walletSettlementDetail(77);
      expect(result.isFailure, isTrue);
    });

    test('stress: repeated 403 responses stay failures', () async {
      final api = apiWith(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'You cannot view this settlement.'}),
            403,
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        final result = await api.walletSettlementDetail(i + 1);
        expect(result.isFailure, isTrue);
      }
    });
  });
}
