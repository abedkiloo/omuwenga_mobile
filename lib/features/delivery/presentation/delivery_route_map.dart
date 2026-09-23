import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/delivery_route_geometry.dart';

class DeliveryRouteMapCard extends StatelessWidget {
  const DeliveryRouteMapCard({
    super.key,
    required this.geometry,
    this.onStopTap,
    this.usePlatformMap = true,
  });

  final DeliveryRouteGeometry geometry;
  final ValueChanged<int>? onStopTap;
  final bool usePlatformMap;

  @override
  Widget build(BuildContext context) {
    final useGoogle = usePlatformMap && !const bool.fromEnvironment('FLUTTER_TEST');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: useGoogle
              ? GoogleDeliveryRouteMap(geometry: geometry, onStopTap: onStopTap)
              : FallbackDeliveryRouteMap(
                  geometry: geometry,
                  onStopTap: onStopTap,
                ),
        ),
        if (geometry.source == 'straight')
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Road line is a straight fallback until the Routes API key is set.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        if (geometry.depot?.placeholder == true)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Shop pin is a Nairobi default. Save the branch depot lat/lng.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
      ],
    );
  }
}

class FallbackDeliveryRouteMap extends StatelessWidget {
  const FallbackDeliveryRouteMap({
    super.key,
    required this.geometry,
    this.onStopTap,
  });

  final DeliveryRouteGeometry geometry;
  final ValueChanged<int>? onStopTap;

  @override
  Widget build(BuildContext context) {
    final pins = geometry.pins;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0D7DE)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final pin in pins)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: pin.isDepot
                    ? const Key('delivery_map_depot')
                    : Key('delivery_map_stop_${pin.stopId}'),
                onTap: pin.isDepot || pin.stopId == null
                    ? null
                    : () => onStopTap?.call(pin.stopId!),
                child: Text(
                  pin.isDepot
                      ? 'Shop · ${pin.label}'
                      : '#${pin.sequence} · ${pin.label}',
                ),
              ),
            ),
          if (pins.isEmpty)
            const Text('No pins on this route yet.'),
        ],
      ),
    );
  }
}

class GoogleDeliveryRouteMap extends StatelessWidget {
  const GoogleDeliveryRouteMap({
    super.key,
    required this.geometry,
    this.onStopTap,
  });

  final DeliveryRouteGeometry geometry;
  final ValueChanged<int>? onStopTap;

  @override
  Widget build(BuildContext context) {
    final pins = geometry.pins;
    final path = geometry.path
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final start = path.isNotEmpty
        ? path.first
        : const LatLng(-1.2921, 36.8219);
    return GoogleMap(
      key: const Key('delivery_google_map'),
      initialCameraPosition: CameraPosition(target: start, zoom: 13),
      markers: {
        for (final pin in pins)
          Marker(
            markerId: MarkerId(pin.isDepot ? 'depot' : 'stop-${pin.stopId}'),
            position: LatLng(pin.latitude, pin.longitude),
            infoWindow: InfoWindow(title: pin.label),
            onTap: pin.isDepot || pin.stopId == null
                ? null
                : () => onStopTap?.call(pin.stopId!),
          ),
      },
      polylines: {
        if (path.length >= 2)
          Polyline(
            polylineId: const PolylineId('planned'),
            points: path,
            width: 4,
            color: const Color(0xFF1D4ED8),
          ),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
    );
  }
}
