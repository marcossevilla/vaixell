import 'package:theseus_cli/src/engine/diff_result.dart';
import 'package:theseus_cli/src/engine/violation.dart';
import 'package:theseus_cli/src/report/report.dart';
import 'package:theseus_cli/src/report/reporter.dart';

/// Prints violations as human-readable lines.
///
/// Each violation is one line, followed by a summary line:
///
/// ```text
/// <path>:<line>:<column>: <severity>: <message> [<id>]
/// ```
///
/// Diff and baseline reports list the new violations the same way, then
/// one `Fixed: <id>` line per fixed violation.
class TextReporter implements Reporter {
  /// Creates a reporter that writes to [out].
  const new(this.out);

  /// Where the report is written.
  final StringSink out;

  @override
  void write(Report report) => switch (report.diff) {
    final diff? => reportDiff(diff),
    null => this.report(report.violations),
  };

  /// Writes [violations] and a summary.
  void report(List<Violation> violations) {
    violations.forEach(_writeViolation);
    out.writeln(switch (violations.length) {
      0 => 'No violations found.',
      1 => '1 violation found.',
      final n => '$n violations found.',
    });
  }

  /// Writes the new violations in [diff], the fixed ids and a summary.
  void reportDiff(DiffResult diff) {
    diff.added.forEach(_writeViolation);
    for (final id in diff.fixed) {
      out.writeln('Fixed: $id');
    }
    final added = diff.added.length;
    out.writeln(
      '$added new violation${added == 1 ? '' : 's'}, '
      '${diff.fixed.length} fixed.',
    );
  }

  void _writeViolation(Violation v) => out.writeln(
    '${v.path}:${v.line}:${v.column}: ${v.severity.name}: '
    '${v.message} [${v.id}]',
  );
}
