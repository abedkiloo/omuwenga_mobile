import 'package:completebyte_pos_mobile/design_system/chrome/cb_collapsible_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collapsible chrome toggles with caret', (tester) async {
    var collapsed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: CbCollapsibleChrome(
                collapsed: collapsed,
                onToggle: () => setState(() => collapsed = !collapsed),
                collapsedLabel: 'Filters & summary',
                collapsedSummary: '12 sales',
                child: const Text('Expanded chrome body'),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Expanded chrome body'), findsOneWidget);
    expect(find.byKey(const Key('chrome_collapse')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chrome_collapse')));
    await tester.pumpAndSettle();

    expect(find.text('Expanded chrome body'), findsNothing);
    expect(find.text('Filters & summary'), findsOneWidget);
    expect(find.byKey(const Key('chrome_expand')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chrome_expand')));
    await tester.pumpAndSettle();

    expect(find.text('Expanded chrome body'), findsOneWidget);
  });

  testWidgets('chrome list column stays inside short and keyboard heights', (
    tester,
  ) async {
    final cases = <(Size, double)>[
      (const Size(320, 568), 0),
      (const Size(320, 568), 300),
      (const Size(375, 667), 336),
      (const Size(414, 896), 336),
      (const Size(568, 320), 0),
      (const Size(320, 480), 220),
    ];

    for (final (size, inset) in cases) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              viewInsets: EdgeInsets.only(bottom: inset),
            ),
            child: const Scaffold(
              resizeToAvoidBottomInset: false,
              body: CbChromeListColumn(
                chrome: Column(
                  children: [
                    SizedBox(height: 80, child: Text('chrome header')),
                    SizedBox(height: 160, child: Text('chrome range')),
                    SizedBox(height: 140, child: Text('chrome totals')),
                  ],
                ),
                stickyBelow: Padding(
                  padding: EdgeInsets.all(8),
                  child: TextField(key: Key('chrome_search')),
                ),
                filters: SizedBox(height: 44, child: Text('filter chips')),
                body: ColoredBox(
                  color: Color(0x11000000),
                  child: Center(child: Text('list body')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size inset=$inset');
      expect(find.byKey(const Key('chrome_search')), findsOneWidget);
      expect(find.text('list body'), findsOneWidget);
      if (inset > 24) {
        expect(find.text('filter chips'), findsNothing);
        expect(find.text('chrome header'), findsNothing);
      } else {
        expect(find.byKey(const Key('chrome_list_scroll')), findsOneWidget);
      }
    }
  });
}
