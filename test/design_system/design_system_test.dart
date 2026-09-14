import 'package:completebyte_pos_mobile/core/theme/app_theme.dart';
import 'package:completebyte_pos_mobile/core/theme/app_typography.dart';
import 'package:completebyte_pos_mobile/design_system/buttons/cb_primary_button.dart';
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
}
