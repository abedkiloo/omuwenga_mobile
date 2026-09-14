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
