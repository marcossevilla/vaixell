import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/engine/generated_files.dart';
import 'package:vaixell/src/engine/package.dart';
import 'package:vaixell/src/engine/violation_ids.dart';
import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/registry.dart';
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
  /// Returns the violations, sorted by path, line and column.
  Future<List<Violation>> run({
    required SourceTree tree,
    required List<Package> packages,
  }) async {
    final violations = <Violation>[];
    for (final package in packages) {
      final rules = [
        for (final rule in const RuleRegistry().all)
          if (package.config.severities[rule.id] case final severity?)
            (rule, severity),
      ];
      for (final path in await _dartFiles(tree, package)) {
        violations.addAll(_check(package, path, await tree.read(path), rules));
      }
    }
    return violations..sort(_compare);
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

  List<Violation> _check(
    Package package,
    String path,
    String content,
    List<(Rule, Severity)> rules,
  ) {
    final file = const DartFileParser().parse(
      path: path,
      content: content,
      packageRoot: package.path,
    );
    final result = const AstBridge().resultOf(file);
    final found = switch (file.errors) {
      [] => _findings(file, rules),
      final errors => [_parseError(package, errors)],
    }..sort((a, b) => a.$3.offset.compareTo(b.$3.offset));

    final ids = ViolationIds();
    return [
      for (final (rule, severity, finding) in found)
        _violation(result, path, rule, severity, finding, ids),
    ];
  }

  List<(String, Severity, Finding)> _findings(
    DartFile file,
    List<(Rule, Severity)> rules,
  ) => [
    for (final (rule, severity) in rules)
      if (rule.shouldCheck(file))
        for (final finding in rule.check(file)) (rule.id, severity, finding),
  ];

  /// The only finding of a file that doesn't parse, at its first error.
  (String, Severity, Finding) _parseError(
    Package package,
    List<SyntaxError> errors,
  ) {
    final [first, ...rest] = errors;
    return (
      Config.parseErrorId,
      package.config.severities[Config.parseErrorId] ?? Severity.error,
      Finding(
        offset: first.offset,
        message:
            'Syntax error: ${first.message}'
            '${rest.isEmpty ? '' : ' (and ${rest.length} more)'}',
      ),
    );
  }

  Violation _violation(
    ParseStringResult result,
    String path,
    String rule,
    Severity severity,
    Finding finding,
    ViolationIds ids,
  ) {
    final location = result.lineInfo.getLocation(finding.offset);
    return Violation(
      id: ids.next(rule: rule, path: path, symbol: finding.symbol),
      rule: rule,
      severity: severity,
      path: path,
      line: location.lineNumber,
      column: location.columnNumber,
      message: finding.message,
    );
  }

  int _compare(Violation a, Violation b) {
    final byPath = a.path.compareTo(b.path);
    if (byPath != 0) return byPath;
    final byLine = a.line.compareTo(b.line);
    if (byLine != 0) return byLine;
    return a.column.compareTo(b.column);
  }
}
