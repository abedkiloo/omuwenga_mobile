/// App version shown on About — keep in sync with `pubspec.yaml` `version:`.
///
/// Format is `versionName+buildNumber` (e.g. `1.0.0+1`). Store staff use
/// these when reporting bugs; support uses them to match release notes.
abstract final class AppBuildInfo {
  static const versionName = '1.0.0';
  static const buildNumber = '1';

  /// Combined label for About, e.g. `1.0.0 (1)`.
  static String get displayLabel => '$versionName ($buildNumber)';

  /// Compact machine form `1.0.0+1`.
  static String get full => '$versionName+$buildNumber';
}
