import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vaixell/src/baseline/baseline.dart';
import 'package:vaixell/src/baseline/baseline_file.dart';
import 'package:vaixell/src/check/package_resolver.dart';
import 'package:vaixell/src/engine/engine.dart';
import 'package:vaixell/src/engine/package.dart';
import 'package:vaixell/src/git/git_runner.dart';
import 'package:vaixell/src/options/config_exception.dart';
import 'package:vaixell/src/report/report.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/source/git_source_tree.dart';
import 'package:vaixell/src/source/source_tree.dart';
import 'package:vaixell/src/violation/diff_result.dart';
import 'package:vaixell/src/violation/violation.dart';

/// {@template check}
/// Checks architecture rules in the packages of a repository.
/// {@endtemplate}
class const Check._({
  /// The repository root directory.
  required final String root,
  required final SourceTree _tree,
  required final PackageResolver _packageResolver,
}) {
  /// {@macro check}
  ///
  /// Configures [rules] for each package, and reads the files of [root] from
  /// [tree], a [FileSystemSourceTree] on [root] by default. [tree] is the
  /// head side of a git-diff comparison, whose base side git reads from the
  /// repository at [root].
  ///
  /// Throws an [ArgumentError] when two [rules] share an id, or one is
  /// `parse-error`.
  factory({
    required String root,
    required List<RuleEntry> rules,
    SourceTree? tree,
  }) {
    final resolvedTree = tree ?? FileSystemSourceTree(Directory(root));
    return Check._(
      root: root,
      tree: resolvedTree,
      packageResolver: PackageResolver(
        root: root,
        tree: resolvedTree,
        rules: rules,
      ),
    );
  }

  static const Engine _engine = Engine();

  /// Checks the packages at [paths], relative to [root], or the discovered
  /// packages when [paths] is empty, and returns the [Report].
  ///
  /// With a [gitDiff] ref, the report is a [ReportMode.diff] comparison
  /// with the merge-base of [gitDiff] and `HEAD`, checking the same
  /// packages with the same configs on both sides, and the ids in
  /// [baseline] are never new. Otherwise, with a [baseline] file path,
  /// relative to [root], the report is a [ReportMode.baseline] comparison
  /// with its ids. Otherwise it's a [ReportMode.full] report.
  ///
  /// Throws an [ArgumentError] when a path is outside [root], a
  /// [ConfigException] when discovery or a config fails, a
  /// [BaselineException] when the baseline file can't be read, and a
  /// [GitException] when git fails.
  Future<Report> call({
    List<String> paths = const [],
    String? gitDiff,
    String? baseline,
  }) async {
    final packages = await _packageResolver(paths);
    final savedBaseline = baseline == null
        ? null
        : await BaselineFile(p.join(root, baseline)).read();
    final ids = savedBaseline?.ids;
    final violations = await _engine.run(tree: _tree, packages: packages);
    if (gitDiff != null) {
      final diff = await _gitDiff(violations, packages, gitDiff);
      return Report.compared(
        ReportMode.diff,
        violations,
        diff.suppress(ids ?? const {}),
      );
    }
    if (ids == null) return Report.full(violations);
    return Report.compared(
      ReportMode.baseline,
      violations,
      DiffResult.compare(base: ids, head: violations),
    );
  }

  /// Compares the [head] violations with the merge-base of [ref] and
  /// `HEAD`, checking the same [packages] on both sides.
  Future<DiffResult> _gitDiff(
    List<Violation> head,
    List<Package> packages,
    String ref,
  ) async {
    final git = GitRunner(root);
    final base = GitSourceTree(git: git, commit: await git.mergeBase(ref));
    try {
      final baseViolations = await _engine.run(tree: base, packages: packages);
      return DiffResult.compare(
        base: baseViolations.map((v) => v.id),
        head: head,
      );
    } finally {
      await base.close();
    }
  }
}
