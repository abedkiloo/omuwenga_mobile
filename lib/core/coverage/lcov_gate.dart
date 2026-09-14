/// LCOV parse + coverage gate helpers used by `tools/check_coverage.dart`.
library;

class CoverageOptions {
  CoverageOptions({
    required this.minPercent,
    required this.paths,
    required this.exclude,
    required this.lcovPath,
  });

  final double minPercent;
  final List<String> paths;
  final List<String> exclude;
  final String lcovPath;

  factory CoverageOptions.parse(List<String> args) {
    var min = 98.0;
    var paths = <String>['lib'];
    var exclude = <String>['lib/main.dart'];
    var lcov = 'coverage/lcov.info';

    for (final arg in args) {
      if (arg.startsWith('--min=')) {
        min = double.parse(arg.substring('--min='.length));
      } else if (arg.startsWith('--paths=')) {
        paths = arg
            .substring('--paths='.length)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (arg.startsWith('--exclude=')) {
        exclude = arg
            .substring('--exclude='.length)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (arg.startsWith('--lcov=')) {
        lcov = arg.substring('--lcov='.length);
      }
    }

    return CoverageOptions(
      minPercent: min,
      paths: paths,
      exclude: exclude,
      lcovPath: lcov,
    );
  }

  bool passes(CoverageSummary summary) =>
      summary.percent + 1e-9 >= minPercent;
}

class LcovRecord {
  LcovRecord({
    required this.sourceFile,
    required this.found,
    required this.hit,
  });

  final String sourceFile;
  final int found;
  final int hit;

  double get percent => found == 0 ? 100.0 : (hit / found) * 100.0;
}

class CoverageSummary {
  CoverageSummary({required this.found, required this.hit});

  final int found;
  final int hit;

  double get percent => found == 0 ? 100.0 : (hit / found) * 100.0;
}

List<LcovRecord> parseLcov(String contents) {
  final records = <LcovRecord>[];
  String? currentFile;
  var found = 0;
  var hit = 0;

  void flush() {
    if (currentFile != null) {
      records.add(LcovRecord(sourceFile: currentFile!, found: found, hit: hit));
    }
    currentFile = null;
    found = 0;
    hit = 0;
  }

  for (final rawLine in contents.split('\n')) {
    final line = rawLine.trimRight();
    if (line.startsWith('SF:')) {
      flush();
      currentFile = line.substring(3).replaceAll('\\', '/');
    } else if (line.startsWith('LF:')) {
      found = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit = int.parse(line.substring(3));
    } else if (line == 'end_of_record') {
      flush();
    }
  }
  flush();
  return records;
}

List<LcovRecord> filterRecords(
  List<LcovRecord> records, {
  required List<String> includePrefixes,
  required List<String> excludeExact,
}) {
  return records.where((record) {
    final path = _normalizeSource(record.sourceFile);
    for (final ex in excludeExact) {
      final normalizedEx = _normalizeSource(ex);
      if (path == normalizedEx || path.endsWith('/$normalizedEx') || path.endsWith(normalizedEx)) {
        return false;
      }
    }
    return includePrefixes.any((prefix) {
      final p = _normalizeSource(prefix);
      return path.contains(p);
    });
  }).toList();
}

String _normalizeSource(String path) => path.replaceAll('\\', '/');

CoverageSummary summarize(List<LcovRecord> records) {
  var found = 0;
  var hit = 0;
  for (final r in records) {
    found += r.found;
    hit += r.hit;
  }
  return CoverageSummary(found: found, hit: hit);
}
