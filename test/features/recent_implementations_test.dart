import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/design_system/chrome/cb_collapsible_chrome.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/customer.dart';
import 'package:completebyte_pos_mobile/features/field_orders/application/visit_order_controller.dart';
import 'package:completebyte_pos_mobile/features/field_orders/data/field_orders_api.dart';
import 'package:completebyte_pos_mobile/features/field_orders/domain/site_pin.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/product_variant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

VisitOrderController _controller(MockClient client) {
  return VisitOrderController(
    FieldOrdersApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: InMemoryTokenStore(),
        httpClient: client,
      ),
    ),
  );
}

void main() {
  group('VisitOrderController.goBack', () {
    late VisitOrderController controller;

    setUp(() {
      controller = _controller(
        MockClient((_) async => http.Response('{}', 200)),
      );
    });

    test('returns false on first step', () {
      expect(controller.state.step, VisitOrderStep.customer);
      expect(controller.goBack(), isFalse);
      expect(controller.state.step, VisitOrderStep.customer);
    });

    test('walks back through products → location → review', () {
      controller
        ..selectCustomer(
          const CustomerSummary(id: 1, name: 'Ada', phone: '0700'),
        )
        ..goTo(VisitOrderStep.products);
      expect(controller.goBack(), isTrue);
      expect(controller.state.step, VisitOrderStep.customer);

      controller.goTo(VisitOrderStep.products);
      controller.addProduct(
        const CatalogProduct(id: 2, name: 'Zip', price: 10),
      );
      controller.goTo(VisitOrderStep.location);
      expect(controller.goBack(), isTrue);
      expect(controller.state.step, VisitOrderStep.products);

      controller
        ..goTo(VisitOrderStep.location)
        ..setPin(const SitePin(latitude: -1.2, longitude: 36.8))
        ..goTo(VisitOrderStep.review);
      expect(controller.goBack(), isTrue);
      expect(controller.state.step, VisitOrderStep.location);
    });
  });

  group('VisitOrderController cart and place', () {
    test('add/update/remove lines and clear customer', () {
      final c = _controller(MockClient((_) async => http.Response('{}', 200)));
      const product = CatalogProduct(id: 2, name: 'Zip', price: 10, sku: 'Z');
      c.addProduct(product);
      c.addProduct(product, qty: 2);
      expect(c.state.lines.single.quantity, 3);
      c.addProduct(
        product,
        variant: const ProductVariant(
          id: 9,
          productId: 2,
          effectivePrice: 12,
          sizeName: 'L',
          sku: 'Z-L',
          stockQuantity: 5,
        ),
      );
      expect(c.state.lines.length, 2);
      c.setQuantity('2', 0);
      expect(c.state.lines.length, 1);
      c.setQuantity('2-9', 4);
      expect(c.state.lines.single.quantity, 4);
      c.removeLine('2-9');
      expect(c.state.lines, isEmpty);
      c
        ..selectCustomer(
          const CustomerSummary(id: 1, name: 'Ada', phone: '0700'),
        )
        ..clearCustomer();
      expect(c.state.customer, isNull);
      expect(c.state.step, VisitOrderStep.customer);
      c
        ..setLandmark('Near gate')
        ..setNotes('Call first');
      expect(c.state.landmark, 'Near gate');
      expect(c.state.notes, 'Call first');
      c.reset();
      expect(c.state.step, VisitOrderStep.customer);
      expect(c.state.notes, '');
    });

    test('placeOrder validates and handles API failure/success', () async {
      final fail = _controller(
        MockClient((_) async => http.Response('{"detail":"no"}', 400)),
      );
      expect(await fail.placeOrder(), isFalse);
      expect(fail.state.error, contains('required'));

      fail
        ..selectCustomer(
          const CustomerSummary(id: 1, name: 'Ada', phone: '0700'),
        )
        ..addProduct(const CatalogProduct(id: 2, name: 'Zip', price: 10))
        ..setPin(const SitePin(latitude: -1.2, longitude: 36.8, label: ''));
      expect(await fail.placeOrder(), isFalse);
      expect(fail.state.error, isNotNull);
      expect(fail.state.submitting, isFalse);

      final longFail = _controller(
        MockClient((_) async => http.Response('x' * 300, 500)),
      );
      longFail
        ..selectCustomer(
          const CustomerSummary(id: 1, name: 'Ada', phone: '0700'),
        )
        ..addProduct(const CatalogProduct(id: 2, name: 'Zip', price: 10))
        ..setPin(const SitePin(latitude: -1.2, longitude: 36.8));
      expect(await longFail.placeOrder(), isFalse);
      expect(longFail.state.error!.endsWith('…'), isTrue);

      final ok = _controller(
        MockClient((request) async {
          expect(request.url.path, contains('field-orders/place'));
          return http.Response(
            jsonEncode({
              'id': 77,
              'status': 'submitted',
              'site': 1,
              'customer_name': 'Ada',
              'lines': [],
              'stock_allocated': false,
            }),
            201,
          );
        }),
      );
      ok
        ..selectCustomer(
          const CustomerSummary(id: 1, name: 'Ada', phone: '0700'),
        )
        ..addProduct(
          const CatalogProduct(id: 2, name: 'Zip', price: 10),
          variant: const ProductVariant(
            id: 3,
            productId: 2,
            effectivePrice: 11,
          ),
        )
        ..setPin(
          const SitePin(latitude: -1.2, longitude: 36.8, label: 'Shop'),
        )
        ..setNotes('rush');
      expect(await ok.placeOrder(), isTrue);
      expect(ok.state.placedOrderId, 77);
      expect(ok.state.lines, isEmpty);
    });
  });

  testWidgets('handleChromeScrollCollapse reacts to list scroll', (
    tester,
  ) async {
    var collapsed = false;
    final controller = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              return handleChromeScrollCollapse(
                notification: notification,
                collapsed: collapsed,
                setCollapsed: (value) => collapsed = value,
              );
            },
            child: ListView.builder(
              controller: controller,
              itemCount: 40,
              itemBuilder: (_, i) =>
                  SizedBox(height: 80, child: Text('row $i')),
            ),
          ),
        ),
      ),
    );

    controller.jumpTo(120);
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(collapsed, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(collapsed, isFalse);
  });
}
