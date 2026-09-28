import 'package:completebyte_pos_mobile/features/payments/domain/mpesa_capture.dart';
import 'package:completebyte_pos_mobile/features/payments/presentation/mpesa_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompt and code are distinct capture modes', () {
    expect(isMpesaPrompt(MpesaCaptureMode.prompt), isTrue);
    expect(isMpesaPrompt(MpesaCaptureMode.code), isFalse);
    expect(kMpesaPromptComingSoon, isTrue);
    expect(mpesaPromptIsLive(), isFalse);
    expect(isLiveMpesaPrompt(MpesaCaptureMode.prompt), isFalse);
  });

  testWidgets('prompt payment shows coming soon and stays on code', (
    tester,
  ) async {
    var mode = MpesaCaptureMode.code;
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

    expect(find.byKey(const Key('mpesa_manual_code')), findsOneWidget);
    expect(find.textContaining('Prompt payment'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mpesa_capture_prompt')));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsWidgets);
    expect(find.byKey(const Key('mpesa_manual_code')), findsOneWidget);
    expect(find.byKey(const Key('mpesa_prompt_phone')), findsNothing);
    expect(mode, MpesaCaptureMode.code);

    await tester.enterText(find.byKey(const Key('mpesa_manual_code')), 'QHX7');
    expect(code.text, 'QHX7');
  });

  testWidgets('coming soon ignores forced prompt mode', (tester) async {
    final phone = TextEditingController();
    final code = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MpesaCapture(
            mode: MpesaCaptureMode.prompt,
            onModeChanged: (_) {},
            phoneController: phone,
            codeController: code,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('mpesa_prompt_phone')), findsNothing);
    expect(find.byKey(const Key('mpesa_manual_code')), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });
}
