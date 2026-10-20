import 'package:theseus_cli/src/engine/violation.dart';

/// The violations added and fixed between two runs, compared by id.
class DiffResult {
  /// Creates a result with [added] and [fixed] violations.
  const new({required this.added, required this.fixed});

  /// Compares the violations of a [base] run with those of a [head] run.
  factory compare({
    required List<Violation> base,
    required List<Violation> head,
  }) {
    final baseIds = {for (final v in base) v.id};
    final headIds = {for (final v in head) v.id};
    return DiffResult(
      added: [
        for (final v in head)
          if (!baseIds.contains(v.id)) v,
      ],
      fixed: [
        for (final v in base)
          if (!headIds.contains(v.id)) v,
      ],
    );
  }

  /// Violations in the head run whose ids aren't in the base run.
  final List<Violation> added;

  /// Violations in the base run whose ids aren't in the head run.
  final List<Violation> fixed;
}
