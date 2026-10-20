import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:theseus_cli/src/engine/generated_files.dart';
import 'package:theseus_cli/src/engine/violation.dart';
import 'package:theseus_cli/src/engine/violation_ids.dart';
import 'package:theseus_cli/src/rules/registry.dart';
import 'package:theseus_cli/src/rules/rule.dart';
import 'package:theseus_cli/src/source/source_tree.dart';

/// Runs rules over the Dart files of a package.
class Engine {
  /// Creates an engine that reads files from [tree] and checks them with
  /// [rules], which defaults to every registered rule.
  Engine({required this.tree, List<Rule>? rules})
    : rules = rules ?? const RuleRegistry().all;

  /// The files to check.
  final SourceTree tree;

  /// The rules to run.
  final List<Rule> rules;

  /// Checks every non-generated Dart file under `lib/` and returns the
  /// violations, sorted by path, line and column.
  Future<List<Violation>> run() async {
    final violations = <Violation>[];
    for (final path in await _dartFiles()) {
      violations.addAll(_check(path, await tree.read(path)));
    }
    return violations..sort(_compare);
  }

  Future<List<String>> _dartFiles() async {
    const generated = GeneratedFiles();
    return [
      for (final path in await tree.listFiles('lib'))
        if (path.endsWith('.dart') && !generated.matches(path)) path,
    ];
  }

  List<Violation> _check(String path, String content) {
    final result = parseString(
      content: content,
      path: path,
      throwIfDiagnostics: false,
    );
    final file = ParsedFile(path: path, result: result);
    final found = <(Rule, Finding)>[
      for (final rule in rules)
        if (!file.hasErrors || rule.checksFilesWithErrors)
          for (final finding in rule.check(file)) (rule, finding),
    ]..sort((a, b) => a.$2.offset.compareTo(b.$2.offset));

    final ids = ViolationIds();
    return [
      for (final (rule, finding) in found) _violation(file, rule, finding, ids),
    ];
  }

  Violation _violation(
    ParsedFile file,
    Rule rule,
    Finding finding,
    ViolationIds ids,
  ) {
    final location = file.result.lineInfo.getLocation(finding.offset);
    return Violation(
      id: ids.next(rule: rule.id, path: file.path, symbol: finding.symbol),
      rule: rule.id,
      severity: rule.defaultSeverity,
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
