import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/engine/package.dart';
import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/built_in_rule.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/source/source_tree.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Runs rules over the Dart files of packages.
class const Engine() {
  /// Creates an engine.
  this;

  /// The suffixes of files produced by code generators, which aren't
  /// checked.
  static const List<String> _generatedSuffixes = [
    '.g.dart',
    '.freezed.dart',
    '.gr.dart',
    '.gen.dart',
    '.mocks.dart',
    '.pb.dart',
    '.pbenum.dart',
    '.pbgrpc.dart',
    '.pbjson.dart',
    '.pbserver.dart',
  ];

  /// Reads files from [tree] and checks every Dart file under each of the
  /// [packages]' `lib/` that isn't generated or excluded by its config, with
  /// the rules enabled in that config. A file that doesn't parse only gets a
  /// `parse-error`, which is always on.
  ///
  /// Returns the violations in an unmodifiable list, sorted by path, line
  /// and column, and in the order of the rules at the same position.
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
    return List.unmodifiable([
      for (final violations in byPath.values) ...violations,
    ]);
  }

  Future<List<String>> _dartFiles(SourceTree tree, Package package) async {
    return [
      for (final path in await tree.listFiles(
        p.posix.join(package.path, 'lib'),
      ))
        if (path.endsWith('.dart') &&
            !_generatedSuffixes.any(path.endsWith) &&
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
    mergeSort(
      found,
      compare: (a, b) => a.finding.offset.compareTo(b.finding.offset),
    );

    final counts = <String, int>{};
    return [for (final finding in found) finding.violation(file, counts)];
  }

  List<_Found> _findings(DartFile file, List<ConfiguredRule> rules) => [
    for (final ConfiguredRule(:rule, :severity) in rules)
      if (rule.shouldCheck(file))
        for (final finding in rule.check(file))
          _Found(
            rule.id,
            severity,
            finding,
            docs: switch (rule) {
              final BuiltInRule rule => rule.docs,
              _ => null,
            },
          ),
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
      docs: const RuleDocs(Config.parseErrorId).url,
    );
  }
}

/// A [finding] of the rule [rule] in a file, reported at [severity], with
/// the rule's [docs], if any.
final class const _Found(
  final String rule,
  final Severity severity,
  final Finding finding, {
  final Uri? docs,
}) {
  /// The violation in [file], with a stable id that leaves out line
  /// numbers, so moving code doesn't change it.
  ///
  /// [counts] holds how often each id has occurred in [file] so far, in
  /// source order: the second occurrence of an id gets `#2`, the third `#3`,
  /// and so on.
  Violation violation(DartFile file, Map<String, int> counts) {
    final symbol = finding.symbol;
    final base = symbol == null
        ? '$rule:${file.path}'
        : '$rule:${file.path}:$symbol';
    final count = counts.update(base, (n) => n + 1, ifAbsent: () => 1);
    return Violation(
      id: count == 1 ? base : '$base#$count',
      rule: rule,
      severity: severity,
      path: file.path,
      line: file.lineAt(finding.offset),
      column: file.columnAt(finding.offset),
      message: finding.message,
      docs: docs,
    );
  }
}
