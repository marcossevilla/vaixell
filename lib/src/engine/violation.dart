/// How a violation affects the exit code.
enum Severity {
  /// Reported, but doesn't fail the run.
  warning,

  /// Reported, and fails the run.
  error,
}

/// A rule violation found in a source file.
class Violation {
  /// Creates a violation.
  const Violation({
    required this.id,
    required this.rule,
    required this.severity,
    required this.path,
    required this.line,
    required this.column,
    required this.message,
  });

  /// The stable identity of the violation, independent of line numbers.
  ///
  /// The format is `<rule>:<path>` or `<rule>:<path>:<symbol>`, with `#n`
  /// appended to the n-th occurrence of the same id in a file.
  final String id;

  /// The id of the rule that produced the violation.
  final String rule;

  /// The severity of the violation.
  final Severity severity;

  /// The POSIX path of the file, relative to the repository root.
  final String path;

  /// The 1-based line of the violation.
  final int line;

  /// The 1-based column of the violation.
  final int column;

  /// A human-readable description of the violation.
  final String message;

  @override
  String toString() => 'Violation($id at $path:$line:$column)';
}
