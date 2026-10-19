import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/pos/application/product_catalog_paging.dart';
import 'package:completebyte_pos_mobile/features/pos/data/pos_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  PosApi apiWith(MockClient client) {
    return PosApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: InMemoryTokenStore(),
        httpClient: client,
      ),
    );
  }

  test('refresh with empty search clears prior search results', () async {
    final calls = <String>[];
    final api = apiWith(
      MockClient((request) async {
        calls.add(request.url.query);
        final q = request.url.queryParameters['search'] ?? '';
        final results = q.isEmpty
            ? [
                {
                  'id': 1,
                  'name': 'All products item',
                  'selling_price': '10',
                  'stock_quantity': 5,
                },
              ]
            : [
                {
                  'id': 9,
                  'name': 'Search hit',
                  'selling_price': '20',
                  'stock_quantity': 3,
                },
              ];
        return http.Response(
          jsonEncode({
            'count': results.length,
            'next': null,
            'previous': null,
            'results': results,
          }),
          200,
        );
      }),
    );

    final catalog = ProductCatalogPaging();
    await catalog.refresh(api, search: 'nail');
    expect(catalog.query, 'nail');
    expect(catalog.items.single.name, 'Search hit');

    // After picking a product, POS clears search and reloads the browse list.
    await catalog.refresh(api, search: '');
    expect(catalog.query, '');
    expect(catalog.items.single.name, 'All products item');
    expect(calls.length, 2);
  });
}
