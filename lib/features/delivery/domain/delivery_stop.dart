/// Delivery route / stop domain (S09). Map + gallery first on stop UI.
enum DeliveryStopStatus {
  pending,
  arrived,
  delivering,
  collected,
  completed,
  failed;

  static DeliveryStopStatus parse(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'arrived':
        return DeliveryStopStatus.arrived;
      case 'delivering':
        return DeliveryStopStatus.delivering;
      case 'collected':
        return DeliveryStopStatus.collected;
      case 'completed':
        return DeliveryStopStatus.completed;
      case 'failed':
        return DeliveryStopStatus.failed;
      default:
        return DeliveryStopStatus.pending;
    }
  }

  String get apiValue => name;
}

class DeliverySiteSnapshot {
  const DeliverySiteSnapshot({
    required this.id,
    this.label = '',
    this.latitude,
    this.longitude,
    this.landmark = '',
    this.photoUrls = const [],
    this.customerName,
    this.customerPhone,
  });

  final int id;
  final String label;
  final double? latitude;
  final double? longitude;
  final String landmark;
  final List<String> photoUrls;
  final String? customerName;
  final String? customerPhone;

  factory DeliverySiteSnapshot.fromJson(Map<String, dynamic> json) {
    final media = json['media'];
    final urls = <String>[];
    if (media is List) {
      for (final m in media) {
        if (m is Map && m['image_url'] != null) {
          urls.add(m['image_url'].toString());
        }
      }
    }
    return DeliverySiteSnapshot(
      id: (json['id'] as num?)?.toInt() ?? 0,
      label: (json['label'] ?? '').toString(),
      latitude: double.tryParse('${json['latitude']}'),
      longitude: double.tryParse('${json['longitude']}'),
      landmark: (json['landmark'] ?? '').toString(),
      photoUrls: urls,
      customerName: json['customer_name']?.toString(),
      customerPhone:
          json['customer_phone']?.toString() ?? json['phone']?.toString(),
    );
  }
}

class DeliveryLine {
  const DeliveryLine({
    required this.productId,
    required this.productName,
    required this.orderedQuantity,
    this.deliveredQuantity = 0,
    this.returnedQuantity = 0,
  });

  final int productId;
  final String productName;
  final double orderedQuantity;
  final double deliveredQuantity;
  final double returnedQuantity;

  DeliveryLine copyWith({double? deliveredQuantity, double? returnedQuantity}) {
    return DeliveryLine(
      productId: productId,
      productName: productName,
      orderedQuantity: orderedQuantity,
      deliveredQuantity: deliveredQuantity ?? this.deliveredQuantity,
      returnedQuantity: returnedQuantity ?? this.returnedQuantity,
    );
  }

  factory DeliveryLine.fromJson(Map<String, dynamic> json) {
    return DeliveryLine(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: (json['product_name'] ?? '').toString(),
      orderedQuantity: double.tryParse('${json['ordered_quantity']}') ?? 0,
      deliveredQuantity: double.tryParse('${json['delivered_quantity']}') ?? 0,
      returnedQuantity: double.tryParse('${json['returned_quantity']}') ?? 0,
    );
  }
}

class PodDraft {
  const PodDraft({
    this.hasSignature = false,
    this.hasPhoto = false,
    this.latitude,
    this.longitude,
    this.notes = '',
  });

  final bool hasSignature;
  final bool hasPhoto;
  final double? latitude;
  final double? longitude;
  final String notes;

  bool get isComplete =>
      hasSignature && hasPhoto && latitude != null && longitude != null;

  PodDraft copyWith({
    bool? hasSignature,
    bool? hasPhoto,
    double? latitude,
    double? longitude,
    String? notes,
    bool clearPin = false,
  }) {
    return PodDraft(
      hasSignature: hasSignature ?? this.hasSignature,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      latitude: clearPin ? null : (latitude ?? this.latitude),
      longitude: clearPin ? null : (longitude ?? this.longitude),
      notes: notes ?? this.notes,
    );
  }
}

class DeliveryStop {
  const DeliveryStop({
    required this.id,
    required this.sequence,
    required this.status,
    required this.site,
    this.fieldOrderId,
    this.lines = const [],
    this.customerName,
    this.customerPhone,
    this.nextStopId,
    this.collectionMethod,
    this.collectionAmount,
    this.requirePod = true,
    this.podComplete = false,
  });

  final int id;
  final int sequence;
  final DeliveryStopStatus status;
  final DeliverySiteSnapshot site;
  final int? fieldOrderId;
  final List<DeliveryLine> lines;
  final String? customerName;
  final String? customerPhone;
  final int? nextStopId;
  final String? collectionMethod;
  final double? collectionAmount;
  final bool requirePod;
  final bool podComplete;

  bool get canComplete {
    if (status != DeliveryStopStatus.collected) return false;
    if (!requirePod) return true;
    return podComplete;
  }

  factory DeliveryStop.fromJson(
    Map<String, dynamic> json, {
    bool requirePod = true,
  }) {
    final siteRaw = json['site'];
    final site = siteRaw is Map
        ? DeliverySiteSnapshot.fromJson(Map<String, dynamic>.from(siteRaw))
        : const DeliverySiteSnapshot(id: 0);
    final linesRaw = json['lines'];
    final lines = <DeliveryLine>[];
    if (linesRaw is List) {
      for (final row in linesRaw) {
        if (row is Map) {
          lines.add(DeliveryLine.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    final pod = json['pod'];
    final podComplete = pod is Map && pod['is_complete'] == true;
    return DeliveryStop(
      id: (json['id'] as num).toInt(),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      status: DeliveryStopStatus.parse(json['status']?.toString()),
      site: site,
      fieldOrderId: (json['field_order_id'] as num?)?.toInt(),
      lines: lines,
      customerName: json['customer_name']?.toString() ?? site.customerName,
      customerPhone: json['customer_phone']?.toString() ?? site.customerPhone,
      nextStopId: (json['next_stop_id'] as num?)?.toInt(),
      collectionMethod: json['collection_method']?.toString(),
      collectionAmount: double.tryParse('${json['collection_amount']}'),
      requirePod: requirePod,
      podComplete: podComplete,
    );
  }
}

class DeliveryRoute {
  const DeliveryRoute({
    required this.id,
    required this.routeDate,
    this.stops = const [],
    this.nextStopId,
  });

  final int id;
  final String routeDate;
  final List<DeliveryStop> stops;
  final int? nextStopId;

  factory DeliveryRoute.fromJson(
    Map<String, dynamic> json, {
    bool requirePod = true,
  }) {
    final stopsRaw = json['stops'];
    final stops = <DeliveryStop>[];
    if (stopsRaw is List) {
      for (final row in stopsRaw) {
        if (row is Map) {
          stops.add(
            DeliveryStop.fromJson(
              Map<String, dynamic>.from(row),
              requirePod: requirePod,
            ),
          );
        }
      }
    }
    return DeliveryRoute(
      id: (json['id'] as num?)?.toInt() ?? 0,
      routeDate: (json['route_date'] ?? '').toString(),
      stops: stops,
      nextStopId: (json['next_stop_id'] as num?)?.toInt(),
    );
  }
}

/// Next incomplete stop by sequence (unit-tested selection).
DeliveryStop? selectNextStop(List<DeliveryStop> stops) {
  final open = stops.where(
    (s) =>
        s.status != DeliveryStopStatus.completed &&
        s.status != DeliveryStopStatus.failed,
  );
  if (open.isEmpty) return null;
  final sorted = [...open]..sort((a, b) => a.sequence.compareTo(b.sequence));
  return sorted.first;
}

class DeliveryConfig {
  const DeliveryConfig({
    this.requirePodToComplete = true,
    this.allowOfflinePodQueue = true,
    this.canViewHistory = false,
  });

  final bool requirePodToComplete;
  final bool allowOfflinePodQueue;
  final bool canViewHistory;

  factory DeliveryConfig.fromJson(Map<String, dynamic> json) {
    final maps = json['maps'];
    return DeliveryConfig(
      requirePodToComplete: json['require_pod_to_complete'] != false,
      allowOfflinePodQueue: json['allow_offline_pod_queue'] != false,
      canViewHistory: maps is Map && maps['can_view_history'] == true,
    );
  }
}

String localIsoDate([DateTime? now]) {
  final d = now ?? DateTime.now();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${pad(d.month)}-${pad(d.day)}';
}
