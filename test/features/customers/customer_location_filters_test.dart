import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/customers/application/customer_list_paging.dart';
import 'package:completebyte_pos_mobile/features/customers/data/customers_api.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/customer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('CustomerSummary location fields', () {
    test('parses location_valid and builds location line', () {
      final ok = CustomerSummary.fromJson({
        'id': 1,
        'name': 'OK Duka',
        'county': 'Nairobi',
        'sub_county': 'Starehe',
        'ward': 'Landimawe',
        'location_valid': true,
        'location_issue': '',
      });
      expect(ok.locationValid, isTrue);
      expect(ok.needsLocationFix, isFalse);
      expect(ok.locationLine, 'Landimawe · Starehe · Nairobi');

      final bad = CustomerSummary.fromJson({
        'id': 2,
        'name': 'Bad Duka',
        'city': 'JOGOO ROAD',
        'location_valid': false,
        'location_issue': 'missing',
      });
      expect(bad.needsLocationFix, isTrue);
      expect(bad.locationIssueLabel, 'Missing location');
      expect(bad.locationLine, 'JOGOO ROAD');
    });
  });

  group('CustomersApi location query params', () {
    test('sends county and location_status', () async {
      Uri? seen;
      final client = MockClient((request) async {
        seen = request.url;
        return http.Response(
          jsonEncode({
            'count': 1,
            'next': null,
            'results': [
              {
                'id': 9,
                'name': 'Loc',
                'county': 'Nairobi',
                'sub_county': 'Starehe',
                'ward': 'Landimawe',
                'location_valid': true,
              },
            ],
          }),
          200,
        );
      });
      final tokens = InMemoryTokenStore();
      await tokens.writeTokens(access: 'a', refresh: 'r');
      final api = CustomersApi(
        ApiClient(
          env: const AppEnv(
            flavor: AppFlavor.dev,
            apiBaseUrl: 'http://example.com/api',
          ),
          tokenStore: tokens,
          httpClient: client,
        ),
      );
      final page = await api.list(
        county: 'Nairobi',
        locationStatus: 'valid',
      );
      expect(page.isSuccess, isTrue);
      expect(seen!.queryParameters['county'], 'Nairobi');
      expect(seen!.queryParameters['location_status'], 'valid');
      expect(page.getOrThrow().results.single.locationValid, isTrue);
    });
  });

  group('CustomerListPaging location filters', () {
    test('refresh passes location filters on first page and loadMore', () async {
      final seen = <Map<String, String>>[];
      final client = MockClient((request) async {
        seen.add(request.url.queryParameters);
        final page = request.url.queryParameters['page'] ?? '1';
        return http.Response(
          jsonEncode({
            'count': 2,
            'next': page == '1' ? 'http://example.com/api/sales/customers/?page=2' : null,
            'results': [
              {
                'id': int.parse(page),
                'name': 'C$page',
                'location_valid': false,
                'location_issue': 'missing',
              },
            ],
          }),
          200,
        );
      });
      final tokens = InMemoryTokenStore();
      await tokens.writeTokens(access: 'a', refresh: 'r');
      final api = CustomersApi(
        ApiClient(
          env: const AppEnv(
            flavor: AppFlavor.dev,
            apiBaseUrl: 'http://example.com/api',
          ),
          tokenStore: tokens,
          httpClient: client,
        ),
      );
      final paging = CustomerListPaging(pageSize: 1);
      await paging.refresh(
        api,
        locationStatus: CustomerLocationStatus.invalid,
        county: 'Nairobi',
      );
      expect(paging.items, hasLength(1));
      expect(seen.first['location_status'], 'invalid');
      expect(seen.first['county'], 'Nairobi');

      await paging.loadMore(api);
      expect(paging.items, hasLength(2));
      expect(seen.last['location_status'], 'invalid');
      expect(seen.last['county'], 'Nairobi');
      expect(seen.last['page'], '2');
    });
  });
}
