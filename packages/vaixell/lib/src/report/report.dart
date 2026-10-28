import 'package:vaixell/src/engine/diff_result.dart';
import 'package:vaixell/src/violation/violation.dart';

/// How a run decided which violations are new.
enum ReportMode {
  /// Every violation counts.
  full,

  /// Violations are compared with the merge-base of a git ref, and
  /// optionally filtered by a baseline.
  diff,

  /// Violations are compared with a baseline file.
  baseline,
}

/// The result of a run, as reporters see it.
///
/// [toJson] produces the document that `--format=json` prints:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "mode": "diff",
///   "violations": [
///     {
///       "id": "top-level-function:lib/a.dart:foo",
///       "rule": "top-level-function",
///       "severity": "error",
///       "path": "lib/a.dart",
///       "line": 3,
///       "column": 6,
///       "message": "Top-level function `foo` is not allowed. ..."
///     }
///   ],
///   "new": [],
///   "fixed": ["top-level-function:lib/a.dart:bar"],
///   "summary": {
///     "violations": 1,
///     "errors": 1,
///     "warnings": 0,
///     "new": 0,
///     "fixed": 1
///   }
/// }
/// ```
///
/// - `schemaVersion` changes only when the document changes in a way that
///   could break consumers.
/// - `mode` is `full`, `diff` or `baseline`. See [ReportMode].
/// - `violations` lists every violation in the checked code, sorted by
///   path, line and column. See [Violation.toJson].
/// - `new` lists the violations that aren't in the base or baseline, in the
///   same shape. Only `diff` and `baseline` reports have it.
/// - `fixed` lists the sorted ids that are in the base or baseline but no
///   longer occur. Only `diff` and `baseline` reports have it.
/// - `summary` counts `violations`, their `errors` and `warnings`, and, in
///   `diff` and `baseline` reports, `new` and `fixed`.
class Report {
  /// Creates a report for a full run with [violations].
  const new full(this.violations) : mode = ReportMode.full, diff = null;

  /// Creates a report for a run of [mode] with all head [violations] and
  /// the [diff] against the base or baseline.
  const new compared(this.mode, this.violations, DiffResult this.diff);

  /// The version of the JSON document.
  static const int schemaVersion = 1;

  /// How new violations were decided.
  final ReportMode mode;

  /// Every violation in the checked code.
  final List<Violation> violations;

  /// The new and fixed violations, or `null` in a full run.
  final DiffResult? diff;

  /// The violations that decide the exit code: [diff]'s added violations,
  /// or every violation in a full run.
  List<Violation> get failing => diff?.added ?? violations;

  /// Returns the JSON document described in the class docs.
  Map<String, Object?> toJson() {
    final diff = this.diff;
    return {
      'schemaVersion': schemaVersion,
      'mode': mode.name,
      'violations': [for (final v in violations) v.toJson()],
      if (diff != null) ...{
        'new': [for (final v in diff.added) v.toJson()],
        'fixed': diff.fixed,
      },
      'summary': {
        'violations': violations.length,
        'errors': violations.where((v) => v.severity == Severity.error).length,
        'warnings': violations
            .where((v) => v.severity == Severity.warning)
            .length,
        if (diff != null) ...{
          'new': diff.added.length,
          'fixed': diff.fixed.length,
        },
      },
    };
  }
}
