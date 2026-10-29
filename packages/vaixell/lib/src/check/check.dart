import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vaixell/src/baseline/baseline.dart';
import 'package:vaixell/src/check/package_resolver.dart';
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/engine/diff_result.dart';
import 'package:vaixell/src/engine/engine.dart';
import 'package:vaixell/src/engine/package.dart';
import 'package:vaixell/src/git/git_runner.dart';
import 'package:vaixell/src/report/report.dart';
import 'package:vaixell/src/source/git_source_tree.dart';
import 'package:vaixell/src/source/source_tree.dart';
import 'package:vaixell/src/violation/violation.dart';

/// {@template check}
/// Checks architecture rules in the packages of a repository.
/// {@endtemplate}
class Check({
  /// The repository root directory.
  required final String root,
  SourceTree? tree,
  GitRunner? git,
}) {
  /// {@macro check}
  ///
  /// Reads the files of [root] from [tree], a [FileSystemSourceTree] on
  /// [root] by default. [tree] is the head side of a git-diff comparison.
  ///
  /// Runs git with [git], a [GitRunner] in [root] by default.
  this;

  final SourceTree _tree = tree ?? FileSystemSourceTree(Directory(root));
  final GitRunner _git = git ?? GitRunner(root);

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
  /// Throws a [ConfigException] when discovery or a config fails, a
  /// [BaselineException] when the baseline file is missing or malformed,
  /// and a [GitException] when git fails.
  Future<Report> call({
    List<String> paths = const [],
    String? gitDiff,
    String? baseline,
  }) async {
    final packages = await PackageResolver(root: root, tree: _tree)(paths);
    final ids = baseline == null
        ? null
        : (await BaselineFile(p.join(root, baseline)).read()).ids;
    final violations = await Engine(tree: _tree, packages: packages).run();
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
    final base = GitSourceTree(git: _git, commit: await _git.mergeBase(ref));
    try {
      final baseViolations = await Engine(tree: base, packages: packages).run();
      return DiffResult.compare(
        base: baseViolations.map((v) => v.id),
        head: head,
      );
    } finally {
      await base.close();
    }
  }
}
