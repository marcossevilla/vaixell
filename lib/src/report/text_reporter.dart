import 'package:theseus_cli/src/engine/violation.dart';

/// Prints violations as human-readable lines.
///
/// Each violation is one line, followed by a summary line:
///
/// ```text
/// <path>:<line>:<column>: <severity>: <message> [<id>]
/// ```
class TextReporter {
  /// Creates a reporter that writes to [out].
  const TextReporter(this.out);

  /// Where the report is written.
  final StringSink out;

  /// Writes [violations] and a summary.
  void report(List<Violation> violations) {
    for (final v in violations) {
      out.writeln(
        '${v.path}:${v.line}:${v.column}: ${v.severity.name}: '
        '${v.message} [${v.id}]',
      );
    }
    out.writeln(switch (violations.length) {
      0 => 'No violations found.',
      1 => '1 violation found.',
      final n => '$n violations found.',
    });
  }
}
