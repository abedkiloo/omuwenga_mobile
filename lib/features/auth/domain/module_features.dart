/// Server-driven Module Settings flags from login/me ``enabled_modules``.
///
/// Flip features in Module Settings on the web — apps pick up the change on
/// the next login or session refresh (no rebuild).
class ModuleFeatures {
  const ModuleFeatures({
    Map<String, Map<String, bool>> enabled = const {},
    Map<String, Map<String, bool>> defaults = const {},
    Set<String> disabledModules = const {},
  }) : _enabled = enabled,
       _defaults = defaults,
       _disabledModules = disabledModules;

  static const empty = ModuleFeatures();

  final Map<String, Map<String, bool>> _enabled;
  final Map<String, Map<String, bool>> _defaults;
  final Set<String> _disabledModules;

  /// Parse ``enabled_modules`` from auth login / me payloads.
  factory ModuleFeatures.fromEnabledModules(Object? raw) {
    if (raw is! Map) return ModuleFeatures.empty;
    final root = Map<String, dynamic>.from(raw);

    final defaults = <String, Map<String, bool>>{};
    final registry = root['registry'];
    if (registry is Map) {
      final featureDefaults = registry['feature_defaults'];
      if (featureDefaults is Map) {
        featureDefaults.forEach((module, feats) {
          if (feats is! Map) return;
          defaults[module.toString()] = {
            for (final e in feats.entries) e.key.toString(): e.value == true,
          };
        });
      }
    }

    final enabled = <String, Map<String, bool>>{};
    final disabledModules = <String>{};
    root.forEach((key, value) {
      if (key == 'registry' || key == 'catalog' || key.toString().startsWith('_')) {
        return;
      }
      if (value is! Map) return;
      final module = Map<String, dynamic>.from(value);
      final moduleName = key.toString();
      if (module['is_enabled'] == false) {
        disabledModules.add(moduleName);
      }
      final features = module['features'];
      if (features is! Map) return;
      final parsed = <String, bool>{};
      features.forEach((featureKey, featureVal) {
        if (featureVal is Map) {
          parsed[featureKey.toString()] = featureVal['is_enabled'] == true;
        } else if (featureVal is bool) {
          parsed[featureKey.toString()] = featureVal;
        }
      });
      if (parsed.isNotEmpty) {
        enabled[moduleName] = parsed;
      }
    });

    return ModuleFeatures(
      enabled: enabled,
      defaults: defaults,
      disabledModules: disabledModules,
    );
  }

  /// Whether a Module Settings feature is on for this store.
  bool isEnabled(
    String module,
    String feature, {
    bool defaultWhenMissing = true,
  }) {
    if (_disabledModules.contains(module)) return false;
    final row = _enabled[module]?[feature];
    if (row != null) return row;
    final fallback = _defaults[module]?[feature];
    if (fallback != null) return fallback;
    return defaultWhenMissing;
  }

  bool get isDailySalesEnabled => isEnabled('sales', 'daily_sales');
  bool get isRetailPosEnabled => isEnabled('sales', 'pos');
  bool get isSalesHistoryEnabled => isEnabled('sales', 'sales_history');
}
