import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/chrome/cb_sticky_action_bar.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../../design_system/states/async_states.dart';
import '../../pos/application/pos_controllers.dart';
import '../application/customers_controllers.dart';
import '../domain/customer.dart';
import '../../../core/validation/field_types.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({
    super.key,
    this.customerId,
    this.returnToPos = false,
    this.returnCustomer = false,
  });

  final int? customerId;
  final bool returnToPos;

  /// When true, pop with the created [CustomerSummary] instead of navigating away.
  final bool returnCustomer;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  final _nameFocus = FocusNode();
  bool _saving = false;
  String? _error;
  bool _seeded = false;

  bool get _isEdit => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _seedFromDetail(CustomerDetail detail) {
    if (_seeded) return;
    _seeded = true;
    _name.text = detail.name;
    _phone.text = detail.phone ?? '';
    _email.text = detail.email ?? '';
    _notes.text = detail.notes ?? '';
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Customer name is required.');
      _nameFocus.requestFocus();
      return;
    }
    if (name.length < 2) {
      setState(
        () => _error =
            'Customer name must be at least 2 characters, e.g. Wambua Hardware',
      );
      _nameFocus.requestFocus();
      return;
    }
    final phoneErr = phoneValidationMessage(_phone.text);
    if (phoneErr != null) {
      setState(() => _error = phoneErr);
      return;
    }
    final emailErr = emailValidationMessage(_email.text);
    if (emailErr != null) {
      setState(() => _error = emailErr);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = CustomerDraft(
      name: name,
      phone: _phone.text,
      email: _email.text,
      notes: _notes.text,
    );
    final api = ref.read(customersApiProvider);
    final result = _isEdit
        ? await api.update(widget.customerId!, draft)
        : await api.create(draft);
    if (!mounted) return;
    result.when(
      success: (customer) {
        setState(() => _saving = false);
        if (widget.returnCustomer) {
          Navigator.of(context).pop(customer);
        } else if (widget.returnToPos) {
          ref
              .read(cartControllerProvider.notifier)
              .attachCustomer(id: customer.id, name: customer.name);
          context.go(AppRoutes.pos);
        } else if (_isEdit) {
          context.pop();
        } else {
          context.go(AppRoutes.customerDetail(customer.id));
        }
      },
      failure: (e, _) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isEdit ? 'Edit customer' : 'New customer';

    if (_isEdit) {
      final state = ref.watch(customerDetailProvider(widget.customerId!));
      if (state.detail != null) {
        _seedFromDetail(state.detail!);
      } else if (state.loading) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: Text(title)),
          body: const LoadingState(),
        );
      }
    }

    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 24 + keyboard),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          CbSurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Update customer details' : 'Register a customer',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Name is required. Phone helps you find them later on visits and POS.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Basics',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('customer_form_name'),
            controller: _name,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Customer name',
              hintText: 'e.g. Wambua Hardware',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('customer_form_phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+\s-]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Phone',
              hintText: 'e.g. 0712 345 678',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Optional',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('customer_form_email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: kEmailExample,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('customer_form_notes'),
            controller: _notes,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_saving) _save();
            },
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Landmark, contact person, credit terms…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('customer_form_error'),
              style: const TextStyle(color: AppColors.destructive),
            ),
          ],
        ],
      ),
      bottomNavigationBar: CbStickyActionBar(
        primaryKey: const Key('customer_form_save'),
        primaryLabel: _saving
            ? 'Saving…'
            : (_isEdit ? 'Save changes' : 'Save customer'),
        onPrimary: _saving ? null : _save,
      ),
    );
  }
}
