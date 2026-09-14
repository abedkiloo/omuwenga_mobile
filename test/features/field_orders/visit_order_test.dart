import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/agents/presentation/map_pin_picker.dart';
import 'package:completebyte_pos_mobile/features/customers/application/customers_controllers.dart';
import 'package:completebyte_pos_mobile/features/customers/data/customers_api.dart';
import 'package:completebyte_pos_mobile/features/field_orders/application/field_order_controllers.dart';
import 'package:completebyte_pos_mobile/features/field_orders/data/field_orders_api.dart';
import 'package:completebyte_pos_mobile/features/field_orders/presentation/visit_order_page.dart';
import 'package:completebyte_pos_mobile/features/pos/application/pos_controllers.dart';
import 'package:completebyte_pos_mobile/features/pos/data/pos_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('visit order: customer → product → pin → place', (tester) async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.contains('/sales/customers/') && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'results': [
              {'id': 9, 'name': 'Ada', 'phone': '0700'},
            ],
          }),
          200,
        );
      }
      if (path.contains('/products/search/')) {
        return http.Response(
          jsonEncode([
            {
              'id': 12,
              'name': 'Cement',
              'selling_price': 150,
              'has_variants': false,
            },
          ]),
          200,
        );
      }
      if (path.endsWith('/field-orders/place/') && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map;
        expect(body['customer_id'], 9);
        expect(body['lines'], isNotEmpty);
        expect(body['latitude'], isNotNull);
        return http.Response(
          jsonEncode({
            'id': 44,
            'status': 'submitted',
            'site': 1,
            'customer_name': 'Ada',
            'lines': [
              {
                'product_id': 12,
                'product_name': 'Cement',
                'quantity': '1',
                'unit_price': '150.00',
              },
            ],
            'stock_allocated': false,
          }),
          201,
        );
      }
      return http.Response('{}', 200);
    });

    final tokens = InMemoryTokenStore();
    final env = const AppEnv(
      flavor: AppFlavor.dev,
      apiBaseUrl: 'http://example.com/api',
    );
    final apiClient = ApiClient(env: env, tokenStore: tokens, httpClient: client);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvProvider.overrideWithValue(env),
          httpClientProvider.overrideWithValue(client),
          apiClientProvider.overrideWithValue(apiClient),
          customersApiProvider.overrideWithValue(CustomersApi(apiClient)),
          fieldOrdersApiProvider.overrideWithValue(FieldOrdersApi(apiClient)),
          posApiProvider.overrideWithValue(PosApi(apiClient)),
        ],
        child: MaterialApp(
          home: VisitOrderPage(mapBuilder: fakeMapPinPickerBuilder),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('visit_customer_9')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('visit_product_search')), 'cem');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('visit_product_12')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('visit_next_products')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fake_map_surface')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('visit_next_location')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('visit_place_order')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('visit_order_success')), findsOneWidget);
  });
}
