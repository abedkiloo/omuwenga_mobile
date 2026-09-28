import 'package:flutter/material.dart';

/// Password field with a show/hide toggle. Does not stretch on narrow phones.
class CbPasswordField extends StatefulWidget {
  const CbPasswordField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.labelText,
    this.enabled = true,
    this.onSubmitted,
    this.textInputAction,
    this.toggleKey,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String labelText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Key? toggleKey;

  @override
  State<CbPasswordField> createState() => _CbPasswordFieldState();
}

class _CbPasswordFieldState extends State<CbPasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final showLabel = _visible ? 'Hide password' : 'Show password';
    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: !_visible,
      enabled: widget.enabled,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          key: widget.toggleKey,
          tooltip: showLabel,
          onPressed: widget.enabled
              ? () => setState(() => _visible = !_visible)
              : null,
          icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }
}
