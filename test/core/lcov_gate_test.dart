import 'package:completebyte_pos_mobile/core/coverage/lcov_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lcov_gate', () {
    test('parseLcov reads SF/LF/LH records', () {
      const sample = '''
SF:lib/core/result/result.dart
LF:10
LH:10
end_of_record
SF:lib/main.dart
LF:5
LH:1
end_of_record
''';
      final records = parseLcov(sample);
      expect(records, hasLength(2));
      expect(records.first.sourceFile, 'lib/core/result/result.dart');
      expect(records.first.found, 10);
      expect(records.first.hit, 10);
    });

    test('filterRecords includes prefixes and excludes main', () {
      final records = [
        LcovRecord(
          sourceFile: '/app/lib/core/result/result.dart',
          found: 10,
          hit: 10,
        ),
        LcovRecord(sourceFile: '/app/lib/main.dart', found: 5, hit: 1),
        LcovRecord(
          sourceFile: '/app/lib/features/health/data/health_api.dart',
          found: 8,
          hit: 8,
        ),
      ];
      final filtered = filterRecords(
        records,
        includePrefixes: ['lib/core', 'lib/features'],
        excludeExact: ['lib/main.dart'],
      );
      expect(filtered, hasLength(2));
      final summary = summarize(filtered);
      expect(summary.found, 18);
      expect(summary.hit, 18);
      expect(summary.percent, 100);
    });

    test('CoverageOptions.parse and passes gate at 98', () {
      final options = CoverageOptions.parse([
        '--min=98',
        '--paths=lib/core,lib/features',
        '--exclude=lib/main.dart',
        '--lcov=coverage/lcov.info',
      ]);
      expect(options.minPercent, 98);
      expect(options.paths, ['lib/core', 'lib/features']);
      expect(options.exclude, ['lib/main.dart']);
      expect(options.lcovPath, 'coverage/lcov.info');
      expect(options.passes(CoverageSummary(found: 100, hit: 98)), isTrue);
      expect(options.passes(CoverageSummary(found: 100, hit: 97)), isFalse);
      expect(CoverageSummary(found: 0, hit: 0).percent, 100);
      expect(LcovRecord(sourceFile: 'x', found: 0, hit: 0).percent, 100);
    });
  });
}
