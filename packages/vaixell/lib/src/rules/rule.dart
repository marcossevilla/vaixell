import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:vaixell/src/violation/violation.dart';

/// A Dart file that has been parsed without type resolution.
class const ParsedFile({
  /// The POSIX path of the file, relative to the repository root.
  required final String path,

  /// The result of parsing the file.
  required final ParseStringResult result,
}) {
  /// Creates a parsed file at [path] from a parse [result].
  this;

  /// The parsed compilation unit.
  CompilationUnit get unit => result.unit;

  /// Whether the parser reported syntax errors.
  bool get hasErrors => result.errors.isNotEmpty;
}

/// Something a [Rule] found in a file, before it gets an id.
class const Finding({
  /// The character offset of the finding in the file.
  required final int offset,

  /// A human-readable description of the finding.
  required final String message,

  /// The symbol path that identifies the finding within its file, for
  /// example `Foo.bar`, or `null` when the file itself is the subject.
  final String? symbol,
}) {
  /// Creates a finding at [offset] in the file.
  this;
}

/// An architecture rule.
abstract base class const Rule() {
  /// Allows subclasses to be const.
  this;

  /// The id used in config and in violation ids, for example
  /// `top-level-function`.
  String get id;

  /// The severity used when the config doesn't set one.
  Severity get defaultSeverity => Severity.error;

  /// Whether the rule also runs on files that have syntax errors.
  bool get checksFilesWithErrors => false;

  /// Returns the findings for [file].
  List<Finding> check(ParsedFile file);
}
