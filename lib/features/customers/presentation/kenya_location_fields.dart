import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/customers_controllers.dart';
import '../domain/kenya_admin_units.dart';

class KenyaLocationFields extends ConsumerWidget {
  const KenyaLocationFields({
    super.key,
    required this.county,
    required this.subCounty,
    required this.ward,
    required this.onCountyChanged,
    required this.onSubCountyChanged,
    required this.onWardChanged,
  });

  final String county;
  final String subCounty;
  final String ward;
  final ValueChanged<String> onCountyChanged;
  final ValueChanged<String> onSubCountyChanged;
  final ValueChanged<String> onWardChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(kenyaAdminUnitsProvider);
    final fallbackUnits = KenyaAdminUnits(
      counties: const {},
      defaults: KenyaLocationDefaults.fallback,
    );
    return unitsAsync.when(
      loading: () => _Fields(
        county: county,
        subCounty: subCounty,
        ward: ward,
        units: fallbackUnits,
        onCountyChanged: onCountyChanged,
        onSubCountyChanged: onSubCountyChanged,
        onWardChanged: onWardChanged,
      ),
      error: (_, __) => _Fields(
        county: county,
        subCounty: subCounty,
        ward: ward,
        units: fallbackUnits,
        onCountyChanged: onCountyChanged,
        onSubCountyChanged: onSubCountyChanged,
        onWardChanged: onWardChanged,
      ),
      data: (units) => _Fields(
        county: county,
        subCounty: subCounty,
        ward: ward,
        units: units,
        onCountyChanged: onCountyChanged,
        onSubCountyChanged: onSubCountyChanged,
        onWardChanged: onWardChanged,
      ),
    );
  }
}

class _Fields extends StatelessWidget {
  const _Fields({
    required this.county,
    required this.subCounty,
    required this.ward,
    required this.units,
    required this.onCountyChanged,
    required this.onSubCountyChanged,
    required this.onWardChanged,
  });

  final String county;
  final String subCounty;
  final String ward;
  final KenyaAdminUnits units;
  final ValueChanged<String> onCountyChanged;
  final ValueChanged<String> onSubCountyChanged;
  final ValueChanged<String> onWardChanged;

  @override
  Widget build(BuildContext context) {
    final counties = units.sortedCounties();
    final subCounties = units.subCountiesFor(county);
    final wards = units.wardsFor(county, subCounty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Dropdown(
          key: const Key('customer_form_county'),
          label: 'County',
          value: county,
          items: counties,
          onChanged: (value) {
            if (value == null) return;
            onCountyChanged(value);
            final subs = units.subCountiesFor(value);
            if (subs.isNotEmpty) {
              onSubCountyChanged(subs.first);
              final w = units.wardsFor(value, subs.first);
              if (w.isNotEmpty) onWardChanged(w.first);
            }
          },
        ),
        const SizedBox(height: 12),
        _Dropdown(
          key: const Key('customer_form_sub_county'),
          label: 'Sub-county',
          value: subCounty,
          items: subCounties,
          onChanged: (value) {
            if (value == null) return;
            onSubCountyChanged(value);
            final w = units.wardsFor(county, value);
            if (w.isNotEmpty) onWardChanged(w.first);
          },
        ),
        const SizedBox(height: 12),
        _Dropdown(
          key: const Key('customer_form_ward'),
          label: 'Ward',
          value: ward,
          items: wards,
          onChanged: (value) {
            if (value != null) onWardChanged(value);
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Country: Kenya',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = items.contains(value)
        ? value
        : (items.isNotEmpty ? items.first : null);
    return DropdownButtonFormField<String>(
      value: effectiveValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<String>(value: item, child: Text(item)),
      ],
      onChanged: items.isEmpty ? null : onChanged,
    );
  }
}
