import 'package:vaixell/src/engine/violation.dart';

/// The violations added and fixed relative to a base set of ids.
class DiffResult {
  /// Creates a result with [added] violations and [fixed] ids.
  const new({required this.added, required this.fixed});

  /// Compares the violations of a [head] run with the [base] ids, which
  /// come from a base run or a baseline file.
  factory compare({
    required Iterable<String> base,
    required List<Violation> head,
  }) {
    final baseIds = {...base};
    final headIds = {for (final v in head) v.id};
    return DiffResult(
      added: [
        for (final v in head)
          if (!baseIds.contains(v.id)) v,
      ],
      fixed: [
        for (final id in baseIds)
          if (!headIds.contains(id)) id,
      ]..sort(),
    );
  }

  /// Violations in the head run whose ids aren't in the base.
  final List<Violation> added;

  /// Sorted ids in the base that aren't in the head run.
  final List<String> fixed;

  /// Returns a copy without the added violations whose ids are in [ids].
  DiffResult suppress(Set<String> ids) => DiffResult(
    added: [
      for (final v in added)
        if (!ids.contains(v.id)) v,
    ],
    fixed: fixed,
  );
}
