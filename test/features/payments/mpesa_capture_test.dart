import 'package:completebyte_pos_mobile/features/payments/domain/mpesa_capture.dart';
import 'package:completebyte_pos_mobile/features/payments/presentation/mpesa_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompt is the default capture mode', () {
    expect(isMpesaPrompt(MpesaCaptureMode.prompt), isTrue);
    expect(isMpesaPrompt(MpesaCaptureMode.code), isFalse);
  });

  testWidgets('toggles between prompt phone and M-Pesa code', (tester) async {
    var mode = MpesaCaptureMode.prompt;
    final phone = TextEditingController();
    final code = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return MpesaCapture(
                mode: mode,
                onModeChanged: (next) => setState(() => mode = next),
                phoneController: phone,
                codeController: code,
                showErrors: true,
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('mpesa_prompt_phone')), findsOneWidget);
    expect(find.text('Prompt payment'), findsOneWidget);
    expect(find.textContaining('Safaricom'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('mpesa_prompt_phone')),
      '0712345678',
    );
    expect(phone.text, '0712345678');

    await tester.tap(find.byKey(const Key('mpesa_capture_code')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mpesa_manual_code')), findsOneWidget);
    expect(find.text('M-Pesa code *'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('mpesa_manual_code')), 'QHX7');
    expect(code.text, 'QHX7');

    await tester.tap(find.byKey(const Key('mpesa_capture_prompt')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mpesa_prompt_phone')), findsOneWidget);
  });
}
