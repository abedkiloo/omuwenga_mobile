import 'package:completebyte_pos_mobile/features/customers/presentation/location_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('typing a ward keeps that ward and hides the others', (tester) async {
    String chosen = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationSearchField(
            label: 'Ward',
            value: '',
            items: const ['Landimawe', 'Kangemi', 'Nairobi Central'],
            onChanged: (value) => chosen = value,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location_search_Ward')), 'land');
    await tester.pump();
    expect(find.text('Landimawe'), findsOneWidget);
    expect(find.text('Kangemi'), findsNothing);
    await tester.tap(find.byKey(const Key('location_choice_Landimawe')));
    await tester.pumpAndSettle();
    expect(chosen, 'Landimawe');
  });
}
