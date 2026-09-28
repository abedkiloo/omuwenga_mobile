/// How the cashier captures an M-Pesa payment: STK prompt or SMS code.
enum MpesaCaptureMode { prompt, code }

const bool kMpesaPromptComingSoon = true;
const String kMpesaPromptComingSoonMessage = 'Coming soon';

bool mpesaPromptIsLive() => !kMpesaPromptComingSoon;

bool isMpesaPrompt(MpesaCaptureMode mode) => mode == MpesaCaptureMode.prompt;

bool isLiveMpesaPrompt(MpesaCaptureMode mode) =>
    mpesaPromptIsLive() && isMpesaPrompt(mode);
