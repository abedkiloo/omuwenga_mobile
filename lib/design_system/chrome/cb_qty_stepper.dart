import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Opens a number pad so cashiers can type qty (e.g. 100) instead of tapping +.
Future<double?> showCbQtyEditor({
  required BuildContext context,
  required double initial,
  double min = 1,
  double? max,
  String title = 'Set quantity',
}) {
  return showModalBottomSheet<double>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _CbQtyEditorSheet(
      initial: initial,
      min: min,
      max: max,
      title: title,
    ),
  );
}

class _CbQtyEditorSheet extends StatefulWidget {
  const _CbQtyEditorSheet({
    required this.initial,
    required this.min,
    this.max,
    required this.title,
  });

  final double initial;
  final double min;
  final double? max;
  final String title;

  @override
  State<_CbQtyEditorSheet> createState() => _CbQtyEditorSheetState();
}

class _CbQtyEditorSheetState extends State<_CbQtyEditorSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _controller = TextEditingController(
      text: initial == initial.roundToDouble()
          ? initial.round().toString()
          : initial.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null) {
      setState(() => _error = 'Enter a valid number.');
      return;
    }
    if (parsed < widget.min) {
      setState(() => _error = 'Minimum is ${widget.min.round()}.');
      return;
    }
    if (widget.max != null && parsed > widget.max!) {
      setState(() => _error = 'Only ${widget.max!.round()} in stock.');
      return;
    }
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
            ),
            if (widget.max != null) ...[
              const SizedBox(height: 4),
              Text(
                'In stock: ${widget.max!.round()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('cb_qty_editor_field'),
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Quantity',
                hintText: 'e.g. 100',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('cb_qty_editor_save'),
                    onPressed: _submit,
                    child: const Text('Set qty'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// +/- stepper with a tappable value for direct entry (100, not 100 taps).
class CbQtyStepper extends StatelessWidget {
  const CbQtyStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.decrementKey,
    this.incrementKey,
    this.valueKey,
    this.label,
  });

  final double quantity;
  final ValueChanged<double> onChanged;
  final double min;
  final double? max;
  final Key? decrementKey;
  final Key? incrementKey;
  final Key? valueKey;
  final String? label;

  bool get _canDec => quantity > min;
  bool get _canInc => max == null || quantity < max!;

  String get _display {
    if (quantity == quantity.roundToDouble()) {
      return quantity.round().toString();
    }
    return quantity.toString();
  }

  Future<void> _edit(BuildContext context) async {
    final next = await showCbQtyEditor(
      context: context,
      initial: quantity,
      min: min,
      max: max,
    );
    if (next != null) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: label != null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const Spacer(),
        ],
        _CbQtyButton(
          key: decrementKey,
          icon: Icons.remove,
          onTap: _canDec ? () => onChanged(quantity - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Material(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => _edit(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  key: valueKey ?? const Key('cb_qty_value'),
                  _display,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        _CbQtyButton(
          key: incrementKey,
          icon: Icons.add,
          onTap: _canInc ? () => onChanged(quantity + 1) : null,
        ),
      ],
    );
  }
}

class _CbQtyButton extends StatelessWidget {
  const _CbQtyButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppColors.background : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? AppColors.mutedForeground
                : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
