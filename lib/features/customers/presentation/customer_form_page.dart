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
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _landmark = TextEditingController();
  final _contactPerson = TextEditingController();
  final _nameFocus = FocusNode();
  final List<TextEditingController> _goods = [TextEditingController()];
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
    _ownerName.dispose();
    _phone.dispose();
    _email.dispose();
    _city.dispose();
    _landmark.dispose();
    _contactPerson.dispose();
    _nameFocus.dispose();
    for (final controller in _goods) {
      controller.dispose();
    }
    super.dispose();
  }

  void _replaceGoods(List<String> values) {
    for (final controller in _goods) {
      controller.dispose();
    }
    _goods
      ..clear()
      ..addAll(
        values.isEmpty
            ? [TextEditingController()]
            : [for (final value in values) TextEditingController(text: value)],
      );
  }

  void _addGood() {
    setState(() => _goods.add(TextEditingController()));
  }

  void _removeGood(int index) {
    setState(() {
      if (_goods.length == 1) {
        _goods.first.clear();
        return;
      }
      _goods[index].dispose();
      _goods.removeAt(index);
    });
  }

  void _seedFromDetail(CustomerDetail detail) {
    if (_seeded) return;
    _seeded = true;
    _name.text = detail.name;
    _ownerName.text = detail.ownerName ?? '';
    _phone.text = detail.phone ?? '';
    _email.text = detail.email ?? '';
    _city.text = detail.city ?? '';
    _landmark.text = detail.address ?? '';
    _contactPerson.text = detail.contactPerson ?? '';
    _replaceGoods(detail.typicalGoods);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Duka name is required.');
      _nameFocus.requestFocus();
      return;
    }
    if (name.length < 2) {
      setState(
        () => _error =
            'Duka name must be at least 2 characters, e.g. Wambua Hardware',
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
      ownerName: _ownerName.text,
      phone: _phone.text,
      email: _email.text,
      city: _city.text,
      address: _landmark.text,
      contactPerson: _contactPerson.text,
      typicalGoods: [for (final c in _goods) c.text],
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

  Widget _sectionLabel(ThemeData theme, String label, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.mutedForeground,
          ),
          children: [
            if (hint != null)
              TextSpan(
                text: ' $hint',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.mutedForeground,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isEdit ? 'Edit duka' : 'Register duka';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        _isEdit ? 'Update duka details' : 'Register a duka',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Duka name is required. Phone helps you find them later on visits and POS.',
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
          if (_error != null) ...[
            Text(
              _error!,
              key: const Key('customer_form_error'),
              style: const TextStyle(color: AppColors.destructive),
            ),
            const SizedBox(height: 12),
          ],
          _sectionLabel(theme, 'Basics'),
          TextField(
            key: const Key('customer_form_name'),
            controller: _name,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Duka name',
              hintText: 'e.g. Wambua Hardware',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('customer_form_owner_name'),
            controller: _ownerName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: "Owner's name",
              hintText: 'e.g. Jane Wambua',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
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
          _sectionLabel(theme, 'Other details', hint: '(optional)'),
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
            key: const Key('customer_form_city'),
            controller: _city,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'City',
              hintText: 'e.g. Nairobi',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(theme, 'Notes'),
          TextField(
            key: const Key('customer_form_landmark'),
            controller: _landmark,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Landmark',
              hintText: 'Next to the market, opposite the bus stage…',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('customer_form_contact_person'),
            controller: _contactPerson,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Contact person',
              hintText: 'Who to ask for, if not the owner',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(theme, 'Goods they buy most', hint: '(optional)'),
          for (var i = 0; i < _goods.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: Key('customer_form_good_$i'),
                    controller: _goods[i],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Good',
                      hintText: 'e.g. Cement 50kg',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  key: Key('customer_form_remove_good_$i'),
                  onPressed: () => _removeGood(i),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove good',
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('customer_form_add_good'),
              onPressed: _addGood,
              icon: const Icon(Icons.add),
              label: const Text('Add another good'),
            ),
          ),
        ],
        ),
      ),
      bottomNavigationBar: CbStickyActionBar(
        primaryKey: const Key('customer_form_save'),
        primaryLabel: _saving
            ? 'Saving…'
            : (_isEdit ? 'Save changes' : 'Save duka'),
        onPrimary: _saving ? null : _save,
      ),
    );
  }
}
