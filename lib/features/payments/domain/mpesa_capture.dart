/// How the cashier captures an M-Pesa payment: STK prompt or SMS code.
enum MpesaCaptureMode { prompt, code }

bool isMpesaPrompt(MpesaCaptureMode mode) => mode == MpesaCaptureMode.prompt;
