import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/validation/field_types.dart';
import '../domain/mpesa_capture.dart';

/// Interchangeable M-Pesa capture: send a PIN prompt, or type the SMS code.
class MpesaCapture extends StatelessWidget {
  const MpesaCapture({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.phoneController,
    required this.codeController,
    this.promptKey = const Key('mpesa_capture_prompt'),
    this.codeModeKey = const Key('mpesa_capture_code'),
    this.phoneFieldKey = const Key('mpesa_prompt_phone'),
    this.codeFieldKey = const Key('mpesa_manual_code'),
    this.enabled = true,
    this.showErrors = false,
    this.onChanged,
  });

  final MpesaCaptureMode mode;
  final ValueChanged<MpesaCaptureMode> onModeChanged;
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final Key promptKey;
  final Key codeModeKey;
  final Key phoneFieldKey;
  final Key codeFieldKey;
  final bool enabled;
  final bool showErrors;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final promptSelected = mode == MpesaCaptureMode.prompt;
    final phoneErr = phoneValidationMessage(
      phoneController.text,
      required: true,
    );
    final codeErr = mpesaReceiptValidationMessage(codeController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'M-Pesa collection',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ModeChip(
                key: promptKey,
                selected: promptSelected,
                enabled: enabled,
                icon: Icons.phone_android,
                label: 'Prompt payment',
                onTap: () => onModeChanged(MpesaCaptureMode.prompt),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeChip(
                key: codeModeKey,
                selected: !promptSelected,
                enabled: enabled,
                icon: Icons.tag,
                label: 'Add M-Pesa code',
                onTap: () => onModeChanged(MpesaCaptureMode.code),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (promptSelected)
          TextField(
            key: phoneFieldKey,
            controller: phoneController,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Safaricom number *',
              hintText: kPhoneExample,
              helperText: 'Sends a PIN prompt to this phone. $kPhoneHelper',
              helperMaxLines: 3,
              errorText: showErrors ? phoneErr : null,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged?.call(),
          )
        else
          TextField(
            key: codeFieldKey,
            controller: codeController,
            enabled: enabled,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
            ],
            decoration: InputDecoration(
              labelText: 'M-Pesa code *',
              hintText: kMpesaReceiptExample,
              helperText: kMpesaReceiptHelper,
              helperMaxLines: 3,
              errorText: showErrors ? codeErr : null,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged?.call(),
          ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    super.key,
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSoft : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? AppColors.success : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.success : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
