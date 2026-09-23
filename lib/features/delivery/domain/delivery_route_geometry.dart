import 'delivery_stop.dart';

class RouteLatLng {
  const RouteLatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class RouteMapPin {
  const RouteMapPin({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.stopId,
    this.sequence = 0,
    this.isDepot = false,
    this.placeholder = false,
  });

  final int? stopId;
  final int sequence;
  final double latitude;
  final double longitude;
  final String label;
  final bool isDepot;
  final bool placeholder;
}

class DeliveryRouteGeometry {
  const DeliveryRouteGeometry({
    this.routeId,
    this.routeDate = '',
    this.deliveryAgentId,
    this.deliveryAgentName = '',
    this.encodedPolyline = '',
    this.source = '',
    this.depot,
    this.path = const [],
    this.stops = const [],
  });

  final int? routeId;
  final String routeDate;
  final int? deliveryAgentId;
  final String deliveryAgentName;
  final String encodedPolyline;
  final String source;
  final RouteMapPin? depot;
  final List<RouteLatLng> path;
  final List<RouteMapPin> stops;

  List<RouteMapPin> get pins {
    return [
      if (depot != null) depot!,
      ...stops.where((s) => !s.isDepot),
    ];
  }

  factory DeliveryRouteGeometry.fromJson(Map<String, dynamic> json) {
    if (json['encoded_polyline'] == null &&
        json['depot'] == null &&
        json['path'] == null) {
      throw FormatException('Not a route geometry payload');
    }
    final depotRaw = json['depot'];
    RouteMapPin? depot;
    if (depotRaw is Map) {
      final lat = double.tryParse('${depotRaw['latitude']}');
      final lng = double.tryParse('${depotRaw['longitude']}');
      if (lat != null && lng != null) {
        depot = RouteMapPin(
          latitude: lat,
          longitude: lng,
          label: (depotRaw['label'] ?? 'Shop').toString(),
          isDepot: true,
          placeholder: depotRaw['placeholder'] == true,
        );
      }
    }
    final path = <RouteLatLng>[];
    final pathRaw = json['path'];
    if (pathRaw is List) {
      for (final row in pathRaw) {
        if (row is Map) {
          final lat = double.tryParse('${row['latitude']}');
          final lng = double.tryParse('${row['longitude']}');
          if (lat != null && lng != null) {
            path.add(RouteLatLng(lat, lng));
          }
        }
      }
    }
    final stops = <RouteMapPin>[];
    final stopsRaw = json['stops'];
    if (stopsRaw is List) {
      for (final row in stopsRaw) {
        if (row is! Map) continue;
        final lat = double.tryParse('${row['latitude']}');
        final lng = double.tryParse('${row['longitude']}');
        if (lat == null || lng == null) continue;
        stops.add(
          RouteMapPin(
            stopId: (row['id'] as num?)?.toInt(),
            sequence: (row['sequence'] as num?)?.toInt() ?? 0,
            latitude: lat,
            longitude: lng,
            label: (row['label'] ?? 'Stop').toString(),
          ),
        );
      }
    }
    return DeliveryRouteGeometry(
      routeId: (json['route_id'] as num?)?.toInt(),
      routeDate: (json['route_date'] ?? '').toString(),
      deliveryAgentId: (json['delivery_agent_id'] as num?)?.toInt(),
      deliveryAgentName: (json['delivery_agent_name'] ?? '').toString(),
      encodedPolyline: (json['encoded_polyline'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      depot: depot,
      path: path,
      stops: stops,
    );
  }

  factory DeliveryRouteGeometry.fromStops(
    List<DeliveryStop> routeStops, {
    RouteMapPin? depot,
  }) {
    final shop = depot ??
        const RouteMapPin(
          latitude: -1.2921,
          longitude: 36.8219,
          label: 'Shop',
          isDepot: true,
          placeholder: true,
        );
    final pins = <RouteMapPin>[];
    final path = <RouteLatLng>[RouteLatLng(shop.latitude, shop.longitude)];
    for (final stop in routeStops) {
      final lat = stop.site.latitude;
      final lng = stop.site.longitude;
      if (lat == null || lng == null) continue;
      final label = stop.site.label.trim().isNotEmpty
          ? stop.site.label
          : 'Stop ${stop.sequence}';
      pins.add(
        RouteMapPin(
          stopId: stop.id,
          sequence: stop.sequence,
          latitude: lat,
          longitude: lng,
          label: label,
        ),
      );
      path.add(RouteLatLng(lat, lng));
    }
    return DeliveryRouteGeometry(
      depot: shop,
      path: path,
      stops: pins,
      source: path.length >= 2 ? 'straight' : '',
    );
  }
}
