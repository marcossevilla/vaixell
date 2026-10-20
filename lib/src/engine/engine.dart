import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:theseus_cli/src/config/config.dart';
import 'package:theseus_cli/src/engine/generated_files.dart';
import 'package:theseus_cli/src/engine/violation.dart';
import 'package:theseus_cli/src/engine/violation_ids.dart';
import 'package:theseus_cli/src/rules/registry.dart';
import 'package:theseus_cli/src/rules/rule.dart';
import 'package:theseus_cli/src/source/source_tree.dart';

/// Runs rules over the Dart files of a package.
class Engine {
  /// Creates an engine that reads files from [tree] and checks them with
  /// the rules enabled in [config].
  new({required this.tree, required this.config});

  /// The files to check.
  final SourceTree tree;

  /// The rules to run, their severities and the files to skip.
  final Config config;

  /// Checks every Dart file under `lib/` that isn't generated or excluded by
  /// [config], and returns the violations, sorted by path, line and column.
  Future<List<Violation>> run() async {
    final rules = [
      for (final rule in const RuleRegistry().all)
        if (config.severities[rule.id] case final severity?) (rule, severity),
    ];
    final violations = <Violation>[];
    for (final path in await _dartFiles()) {
      violations.addAll(_check(path, await tree.read(path), rules));
    }
    return violations..sort(_compare);
  }

  Future<List<String>> _dartFiles() async {
    const generated = GeneratedFiles();
    return [
      for (final path in await tree.listFiles('lib'))
        if (path.endsWith('.dart') &&
            !generated.matches(path) &&
            !config.excludes(path))
          path,
    ];
  }

  List<Violation> _check(
    String path,
    String content,
    List<(Rule, Severity)> rules,
  ) {
    final result = parseString(
      content: content,
      path: path,
      throwIfDiagnostics: false,
    );
    final file = ParsedFile(path: path, result: result);
    final found = <(Rule, Severity, Finding)>[
      for (final (rule, severity) in rules)
        if (!file.hasErrors || rule.checksFilesWithErrors)
          for (final finding in rule.check(file)) (rule, severity, finding),
    ]..sort((a, b) => a.$3.offset.compareTo(b.$3.offset));

    final ids = ViolationIds();
    return [
      for (final (rule, severity, finding) in found)
        _violation(file, rule, severity, finding, ids),
    ];
  }

  Violation _violation(
    ParsedFile file,
    Rule rule,
    Severity severity,
    Finding finding,
    ViolationIds ids,
  ) {
    final location = file.result.lineInfo.getLocation(finding.offset);
    return Violation(
      id: ids.next(rule: rule.id, path: file.path, symbol: finding.symbol),
      rule: rule.id,
      severity: severity,
      path: file.path,
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
