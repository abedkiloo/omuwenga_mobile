import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../../pos/application/pos_controllers.dart';
import '../application/customers_controllers.dart';
import '../domain/customer.dart';

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
  bool _saving = false;
  String? _error;
  bool _seeded = false;

  bool get _isEdit => widget.customerId != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
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
      setState(() => _error = 'Name is required.');
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
    if (_isEdit) {
      final state = ref.watch(customerDetailProvider(widget.customerId!));
      if (state.detail != null) {
        _seedFromDetail(state.detail!);
      } else if (state.loading) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_isEdit ? 'Edit customer' : 'New customer'),
          ),
          body: const LoadingState(),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit customer' : 'New customer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('customer_form_name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('customer_form_phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('customer_form_email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('customer_form_notes'),
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.destructive)),
          ],
          const SizedBox(height: 24),
          CbPrimaryButton(
            key: const Key('customer_form_save'),
            label: _saving ? 'Saving…' : 'Save',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
