/// Documented client defaults — mirrors `be/agents/config.py`.
class SiteVisitConfig {
  const SiteVisitConfig({
    this.minPhotos = 0,
    this.maxPhotos = 10,
    this.maxImageBytes = 2 * 1024 * 1024,
    this.compressQuality = 75,
  });

  final int minPhotos;
  final int maxPhotos;
  final int maxImageBytes;
  final int compressQuality;

  static const defaults = SiteVisitConfig(minPhotos: 0);

  factory SiteVisitConfig.fromJson(Map<String, dynamic> json) {
    return SiteVisitConfig(
      minPhotos: (json['min_site_media'] as num?)?.toInt() ?? 0,
      maxPhotos: (json['max_site_media'] as num?)?.toInt() ?? 10,
      maxImageBytes:
          (json['max_site_image_bytes'] as num?)?.toInt() ?? 2 * 1024 * 1024,
    );
  }
}

class SitePin {
  const SitePin({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.label = '',
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final String label;

  SitePin copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? label,
  }) {
    return SitePin(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      label: label ?? this.label,
    );
  }
}

class LocalSitePhoto {
  const LocalSitePhoto({
    required this.id,
    required this.path,
    required this.bytesLength,
    this.caption = '',
  });

  final String id;
  final String path;
  final int bytesLength;
  final String caption;
}

enum SiteVisitStep { map, photos, customer }

class DeliveryStopViewModel {
  /// Fields the S09 delivery stop UI will need (map + gallery first).
  const DeliveryStopViewModel({
    required this.siteId,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.landmark = '',
    this.customerId,
    this.customerName,
    this.photoUrls = const [],
  });

  final int siteId;
  final String label;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String landmark;
  final int? customerId;
  final String? customerName;
  final List<String> photoUrls;

  factory DeliveryStopViewModel.fromSiteJson(Map<String, dynamic> json) {
    final media = json['media'];
    final urls = <String>[];
    if (media is List) {
      for (final item in media) {
        if (item is Map && item['image_url'] != null) {
          urls.add(item['image_url'].toString());
        }
      }
    }
    return DeliveryStopViewModel(
      siteId: (json['id'] as num).toInt(),
      label: (json['label'] ?? '').toString(),
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      landmark: (json['landmark'] ?? '').toString(),
      customerId: (json['customer'] as num?)?.toInt(),
      customerName: json['customer_name']?.toString(),
      photoUrls: urls,
    );
  }
}
