import 'dart:io';

import 'package:completebyte_pos_mobile/core/coverage/lcov_gate.dart';

/// Fails if line coverage for selected lib paths is below [--min] (default 98).
///
/// ```bash
/// dart run tools/check_coverage.dart --min=98 \
///   --paths=lib/core,lib/design_system,lib/features,lib/app \
///   --exclude=lib/main.dart
/// ```
void main(List<String> args) {
  final options = CoverageOptions.parse(args);
  final file = File(options.lcovPath);
  if (!file.existsSync()) {
    stderr.writeln('Missing ${options.lcovPath}. Run: flutter test --coverage');
    exitCode = 2;
    return;
  }

  final report = parseLcov(file.readAsStringSync());
  final filtered = filterRecords(
    report,
    includePrefixes: options.paths,
    excludeExact: options.exclude,
  );

  if (filtered.isEmpty) {
    stderr.writeln('No source files matched paths=${options.paths}');
    exitCode = 2;
    return;
  }

  final summary = summarize(filtered);
  final pct = summary.percent;
  stdout.writeln(
    'Coverage ${pct.toStringAsFixed(2)}% '
    '(${summary.hit}/${summary.found} lines) over ${filtered.length} files '
    '(min ${options.minPercent}%)',
  );

  if (!options.passes(summary)) {
    for (final record in filtered) {
      if (record.percent + 1e-9 < options.minPercent) {
        stdout.writeln(
          '  below: ${record.sourceFile} '
          '${record.percent.toStringAsFixed(1)}% (${record.hit}/${record.found})',
        );
      }
    }
    exitCode = 1;
  }
}
