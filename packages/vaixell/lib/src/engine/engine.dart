import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/engine/generated_files.dart';
import 'package:vaixell/src/engine/package.dart';
import 'package:vaixell/src/engine/violation_ids.dart';
import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/source/source_tree.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Runs rules over the Dart files of packages.
class const Engine() {
  /// Creates an engine.
  this;

  /// Reads files from [tree] and checks every Dart file under each of the
  /// [packages]' `lib/` that isn't generated or excluded by its config, with
  /// the rules enabled in that config. A file that doesn't parse only gets a
  /// `parse-error`, which is always on.
  ///
  /// Returns the violations, sorted by path, line and column, and in the
  /// order of the rules at the same position.
  Future<List<Violation>> run({
    required SourceTree tree,
    required List<Package> packages,
  }) async {
    final byPath = SplayTreeMap<String, List<Violation>>();
    for (final package in packages) {
      for (final path in await _dartFiles(tree, package)) {
        byPath[path] = _check(package, path, await tree.read(path));
      }
    }
    return [for (final violations in byPath.values) ...violations];
  }

  Future<List<String>> _dartFiles(SourceTree tree, Package package) async {
    const generated = GeneratedFiles();
    return [
      for (final path in await tree.listFiles(
        p.posix.join(package.path, 'lib'),
      ))
        if (path.endsWith('.dart') &&
            !generated.matches(path) &&
            !package.config.excludes(path))
          path,
    ];
  }

  List<Violation> _check(Package package, String path, String content) {
    final file = DartFile.parse(
      path: path,
      content: content,
      packageRoot: package.path,
      packageName: package.name,
    );
    final found = switch (file.errors) {
      [] => _findings(file, package.config.rules),
      final errors => [_parseError(package, errors)],
    };
    mergeSort(found, compare: (a, b) => a.finding.compareTo(b.finding));

    final ids = ViolationIds();
    return [for (final finding in found) finding.violation(file, ids)];
  }

  List<_Found> _findings(DartFile file, List<ConfiguredRule> rules) => [
    for (final ConfiguredRule(:rule, :severity) in rules)
      if (rule.shouldCheck(file))
        for (final finding in rule.check(file))
          _Found(rule.id, severity, finding),
  ];

  /// The only finding of a file that doesn't parse, at its first error.
  _Found _parseError(Package package, List<SyntaxError> errors) {
    final [first, ...rest] = errors;
    return _Found(
      Config.parseErrorId,
      package.config.parseErrorSeverity,
      Finding(
        offset: first.offset,
        message:
            'Syntax error: ${first.message}'
            '${rest.isEmpty ? '' : ' (and ${rest.length} more)'}',
      ),
    );
  }
}

/// A [finding] of the rule [rule] in a file, reported at [severity].
final class const _Found(
  final String rule,
  final Severity severity,
  final Finding finding,
) {
  /// The violation in [file], with the next id from [ids].
  Violation violation(DartFile file, ViolationIds ids) {
    return Violation(
      id: ids.next(rule: rule, path: file.path, symbol: finding.symbol),
      rule: rule,
      severity: severity,
      path: file.path,
      line: file.lineAt(finding.offset),
      column: file.columnAt(finding.offset),
      message: finding.message,
    );
  }
}
