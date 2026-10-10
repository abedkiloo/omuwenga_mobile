class KenyaLocationDefaults {
  const KenyaLocationDefaults({
    required this.county,
    required this.subCounty,
    required this.ward,
  });

  final String county;
  final String subCounty;
  final String ward;

  static const fallback = KenyaLocationDefaults(
    county: 'Nairobi',
    subCounty: 'Starehe',
    ward: 'Landimawe',
  );
}

class KenyaAdminUnits {
  const KenyaAdminUnits({
    required this.counties,
    required this.defaults,
  });

  /// County name → sub-county name → ward names.
  final Map<String, Map<String, List<String>>> counties;
  final KenyaLocationDefaults defaults;

  List<String> sortedCounties() {
    final names = counties.keys.toList()..sort();
    return names;
  }

  List<String> subCountiesFor(String county) {
    final subs = counties[county];
    if (subs == null) return const [];
    final names = subs.keys.toList()..sort();
    return names;
  }

  List<String> wardsFor(String county, String subCounty) {
    final wards = counties[county]?[subCounty];
    if (wards == null) return const [];
    final copy = List<String>.from(wards)..sort();
    return copy;
  }

  factory KenyaAdminUnits.fromJson(Map<String, dynamic> json) {
    final defaultsRaw = json['defaults'];
    final defaults = defaultsRaw is Map
        ? KenyaLocationDefaults(
            county: defaultsRaw['county']?.toString() ??
                KenyaLocationDefaults.fallback.county,
            subCounty: defaultsRaw['sub_county']?.toString() ??
                KenyaLocationDefaults.fallback.subCounty,
            ward: defaultsRaw['ward']?.toString() ??
                KenyaLocationDefaults.fallback.ward,
          )
        : KenyaLocationDefaults.fallback;

    final countiesRaw = json['counties'];
    final counties = <String, Map<String, List<String>>>{};
    if (countiesRaw is Map) {
      for (final countyEntry in countiesRaw.entries) {
        final countyName = countyEntry.key.toString();
        final subMap = countyEntry.value;
        if (subMap is! Map) continue;
        final parsedSubs = <String, List<String>>{};
        for (final subEntry in subMap.entries) {
          final subName = subEntry.key.toString();
          final wardList = subEntry.value;
          if (wardList is List) {
            parsedSubs[subName] = [
              for (final w in wardList)
                if (w != null && w.toString().trim().isNotEmpty) w.toString(),
            ];
          }
        }
        counties[countyName] = parsedSubs;
      }
    }

    return KenyaAdminUnits(counties: counties, defaults: defaults);
  }
}
