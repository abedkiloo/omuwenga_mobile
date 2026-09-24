import 'package:completebyte_pos_mobile/design_system/chrome/cb_bounded_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bounded sheet fits above the keyboard', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showCbBoundedSheet<void>(
                    context: context,
                    builder: (_) => const Text('sheet-body'),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('sheet-body'), findsOneWidget);
    final frame = tester.widget<CbSheetFrame>(find.byType(CbSheetFrame));
    expect(frame.heightFactor, 0.92);
  });

  testWidgets('sheet frame shrinks by the keyboard inset', (tester) async {
    await tester.pumpWidget(
      const Align(
        alignment: Alignment.topCenter,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(400, 800),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CbSheetFrame(
              heightFactor: 0.5,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    final box = tester.renderObject<RenderBox>(find.byType(CbSheetFrame));
    expect(box.size.height, 250);
  });
}
