import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/site_visit.dart';
import 'map_pin_picker.dart';

/// Production Google Maps pin picker (excluded from coverage gate — platform view).
class GoogleMapPinPicker extends StatefulWidget {
  const GoogleMapPinPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final SitePin? selected;
  final ValueChanged<SitePin> onChanged;

  @override
  State<GoogleMapPinPicker> createState() => _GoogleMapPinPickerState();
}

class _GoogleMapPinPickerState extends State<GoogleMapPinPicker> {
  static const _nairobi = LatLng(-1.2921, 36.8219);

  @override
  Widget build(BuildContext context) {
    final pin = widget.selected;
    return GoogleMap(
      key: const Key('google_map_picker'),
      initialCameraPosition: CameraPosition(
        target: pin != null ? LatLng(pin.latitude, pin.longitude) : _nairobi,
        zoom: 15,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: {
        if (pin != null)
          Marker(
            markerId: const MarkerId('site'),
            position: LatLng(pin.latitude, pin.longitude),
          ),
      },
      onTap: (latLng) {
        widget.onChanged(
          SitePin(
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            label: 'Pinned location',
          ),
        );
      },
    );
  }
}

MapPinPickerBuilder get googleMapPinPickerBuilder => (
      context, {
      required selected,
      required onChanged,
    }) {
      return GoogleMapPinPicker(selected: selected, onChanged: onChanged);
    };
