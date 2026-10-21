import 'package:vaixell/src/engine/violation.dart';
import 'package:vaixell/src/report/report.dart';
import 'package:vaixell/src/report/reporter.dart';

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
  void write(Report report) {
    for (final violation in report.failing) {
      out.writeln(describe(violation));
    }
    for (final id in report.diff?.fixed ?? const <String>[]) {
      out.writeln('Fixed: $id');
    }
    out.writeln(summary(report));
  }

  /// Returns the one-line description of [v].
  String describe(Violation v) =>
      '${v.path}:${v.line}:${v.column}: ${v.severity.name}: '
      '${v.message} [${v.id}]';

  /// Returns the summary line for [report], such as `2 violations found.`
  /// or `1 new violation, 0 fixed.`
  String summary(Report report) {
    final diff = report.diff;
    if (diff == null) {
      return switch (report.violations.length) {
        0 => 'No violations found.',
        1 => '1 violation found.',
        final n => '$n violations found.',
      };
    }
    final added = diff.added.length;
    return '$added new violation${added == 1 ? '' : 's'}, '
        '${diff.fixed.length} fixed.';
  }
}
