import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/site_pin.dart';

typedef MapPinPickerBuilder =
    Widget Function(
      BuildContext context, {
      required SitePin? selected,
      required ValueChanged<SitePin> onChanged,
    });

/// Testable map surface — taps set a pin without Google Maps.
class FakeMapPinPicker extends StatelessWidget {
  const FakeMapPinPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final SitePin? selected;
  final ValueChanged<SitePin> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondary,
      child: InkWell(
        key: const Key('fake_map_surface'),
        onTap: () {
          onChanged(
            const SitePin(
              latitude: -1.2921,
              longitude: 36.8219,
              accuracy: 15,
              label: 'Pinned location',
            ),
          );
        },
        child: Center(
          child: Text(
            selected == null ? 'Tap to place pin' : 'Pin set',
            key: const Key('fake_map_status'),
          ),
        ),
      ),
    );
  }
}

MapPinPickerBuilder get fakeMapPinPickerBuilder =>
    (context, {required selected, required onChanged}) {
      return FakeMapPinPicker(selected: selected, onChanged: onChanged);
    };

/// Default for widget tests / offline design; production route injects Google Maps.
MapPinPickerBuilder get defaultMapPinPickerBuilder => fakeMapPinPickerBuilder;
