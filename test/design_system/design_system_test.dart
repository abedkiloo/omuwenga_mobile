import 'package:completebyte_pos_mobile/core/theme/app_theme.dart';
import 'package:completebyte_pos_mobile/core/theme/app_typography.dart';
import 'package:completebyte_pos_mobile/design_system/buttons/cb_primary_button.dart';
import 'package:completebyte_pos_mobile/design_system/chrome/cb_sticky_action_bar.dart';
import 'package:completebyte_pos_mobile/design_system/scaffold/cb_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme and typography build without runtime fonts', () {
    final theme = AppTheme.light(fetchRuntimeFonts: false);
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary.toARGB32(), isNonZero);

    final withFetch = AppTypography.textTheme(fetchRuntimeFonts: true);
    expect(withFetch.bodyLarge, isNotNull);
    final without = AppTypography.textTheme(fetchRuntimeFonts: false);
    expect(without.titleLarge?.fontSize, 20);
    expect(AppTypography.fontFamily, 'PlusJakartaSans');
  });

  testWidgets('CbScaffold and CbPrimaryButton', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CbScaffold(
          title: 'Title',
          body: CbPrimaryButton(label: 'Go', onPressed: () => pressed = true),
        ),
      ),
    );
    expect(find.text('Title'), findsOneWidget);
    await tester.tap(find.text('Go'));
    expect(pressed, isTrue);
  });

  testWidgets('CbStickyActionBar summary secondary and nested safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CbStickyActionBar(
                summary: '3 items',
                summaryTrailing: 'KES 10',
                secondary: const Text('Pay later'),
                primaryLabel: 'Pay now',
                onPrimary: () {},
              ),
              const CbStickyActionBar(
                safeArea: false,
                primaryLabel: 'Register duka',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('KES 10'), findsOneWidget);
    expect(find.text('Pay later'), findsOneWidget);
    expect(find.text('Pay now'), findsOneWidget);
    expect(find.text('Register duka'), findsOneWidget);
  });
}
