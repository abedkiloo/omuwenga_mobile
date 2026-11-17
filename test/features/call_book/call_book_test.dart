import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/core/result/result.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/module_features.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/call_book/application/call_book_controller.dart';
import 'package:completebyte_pos_mobile/features/call_book/data/call_book_api.dart';
import 'package:completebyte_pos_mobile/features/call_book/domain/call_book.dart';
import 'package:completebyte_pos_mobile/features/call_book/presentation/call_book_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

CallBookPageData _page({
  required List<CallBookRow> rows,
  int count = 1,
  int page = 1,
  int weekday = 0,
}) {
  return CallBookPageData(
    summary: CallBookSummary(
      isCallDay: true,
      weekday: weekday,
      callable: 2,
      called: 1,
      notCalled: 1,
      days: const [
        CallDayCount(weekday: 0, callable: 2, called: 1, notCalled: 1),
        CallDayCount(weekday: 1, callable: 0, called: 0, notCalled: 0),
      ],
    ),
    count: count,
    page: page,
    pageSize: kCallBookPageSize,
    results: rows,
  );
}

CallBookRow _row({
  required int id,
  required String name,
  bool called = false,
  bool due = false,
}) {
  return CallBookRow(
    customerId: id,
    name: name,
    phone: '071800000$id',
    county: 'Nairobi',
    subCounty: 'Starehe',
    ward: 'Landimawe',
    weekday: 0,
    calledThisWeek: called,
    callLaterDue: due,
    previousSummary: '',
  );
}

class _FakeApi extends CallBookApi {
  _FakeApi()
      : super(
          ApiClient(
            env: const AppEnv(
              flavor: AppFlavor.dev,
              apiBaseUrl: 'http://example.com/api',
            ),
            tokenStore: InMemoryTokenStore(),
            httpClient: MockClient((request) async => http.Response('{}', 200)),
          ),
        );

  bool saved = false;

  @override
  Future<Result<CallBookPageData>> fetch({
    required int weekday,
    int page = 1,
    int pageSize = kCallBookPageSize,
  }) async {
    if (saved) {
      return Success(_page(rows: const [], count: 0));
    }
    if (page == 2) {
      return Success(_page(
        rows: [_row(id: 50, name: 'Page Two Shop')],
        count: 25,
        page: 2,
      ));
    }
    return Success(_page(
      rows: [
        _row(id: 1, name: 'Not Called Shop'),
        _row(id: 2, name: 'Called Shop', called: true),
      ],
      count: 25,
    ));
  }

  @override
  Future<Result<bool>> mark({
    required int customerId,
    required String outcome,
    String summary = '',
    String followUpOn = '',
    String followUpTime = '',
  }) async {
    saved = true;
    return const Success(true);
  }

  @override
  Future<Result<bool>> hold(int customerId) async => const Success(true);
}

void main() {
  test('a recorded customer stays off the working list', () {
    final rows = visibleCallRows([
      _row(id: 1, name: 'Not Called Shop'),
      _row(id: 2, name: 'Called Shop', called: true),
      _row(id: 3, name: 'Due Shop', called: true, due: true),
    ]);
    expect(rows.map((row) => row.name), ['Not Called Shop', 'Due Shop']);
  });

  test('the book request asks for the uncalled page of ten', () async {
    Uri? seen;
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final api = CallBookApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: MockClient((request) async {
          seen = request.url;
          if (request.url.path.endsWith('/mark/')) {
            return http.Response(
              jsonEncode({'error': 'Could not record this call.'}),
              400,
            );
          }
          return http.Response(
            jsonEncode({
              'summary': {
                'is_call_day': true,
                'weekday': 0,
                'callable': 1,
                'called': 0,
                'not_called': 1,
                'days': [],
              },
              'count': 1,
              'page': 1,
              'page_size': 10,
              'results': [],
            }),
            200,
          );
        }),
      ),
    );
    final page = await api.fetch(weekday: 0, page: 1);
    expect(page.isSuccess, isTrue);
    expect(seen!.queryParameters['status'], 'not_called');
    expect(seen!.queryParameters['page_size'], '10');
    expect(seen!.queryParameters['weekday'], '0');
    final failed = await api.mark(customerId: 4, outcome: 'called');
    expect(failed.isFailure, isTrue);
    expect('${(failed as Failure).error}', 'Could not record this call.');
    expect('${(failed as Failure).error}'.contains('0718'), isFalse);
  });

  test('field sales and a switched-off feature cannot open the call centre', () {
    final grants = PermissionSet([
      const PermissionGrant(module: 'customers', action: 'call_book'),
    ]);
    const staff = UserProfileSnapshot(
      role: 'sales',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
      roleDisplay: 'Sales',
    );
    const field = UserProfileSnapshot(
      role: 'field_sales',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
      roleDisplay: 'Field Sales',
    );
    expect(
      sessionCanUseCallBook(permissions: grants, profile: staff),
      isTrue,
    );
    expect(
      sessionCanUseCallBook(permissions: grants, profile: field),
      isFalse,
    );
    expect(
      sessionCanUseCallBook(
        permissions: grants,
        profile: staff,
        features: ModuleFeatures.fromEnabledModules({
          'customers': {
            'is_enabled': true,
            'features': {'call_book': false},
          },
        }),
      ),
      isFalse,
    );
  });

  testWidgets('pages the list and clears a customer after the call is saved', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [callBookApiProvider.overrideWithValue(_FakeApi())],
        child: const MaterialApp(home: CallBookPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not Called Shop'), findsOneWidget);
    expect(find.text('Called Shop'), findsNothing);
    expect(find.text('Page 1 of 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call_next_page')));
    await tester.pumpAndSettle();
    expect(find.text('Page Two Shop'), findsOneWidget);

    await tester.tap(find.byKey(const Key('call_previous_page')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('call_customer_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('call_save')));
    await tester.pumpAndSettle();
    expect(find.text('Not Called Shop'), findsNothing);
    expect(find.textContaining('already has a result'), findsOneWidget);
  });
}
