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
class const Check._({
  /// The repository root directory.
  required final String root,
  required final SourceTree _tree,
  required final GitRunner _git,
  required final OpenGitSourceTree _openGitSourceTree,
  required final PackageResolver _packageResolver,
  required final Engine _engine,
  required final BaselineFile _baselineFile,
}) {
  /// {@macro check}
  ///
  /// Reads the files of [root] from [tree], a [FileSystemSourceTree] on
  /// [root] by default. [tree] is the head side of a git-diff comparison.
  ///
  /// Runs git with [git], a [GitRunner] in [root] by default, and reads the
  /// git-diff base side from [openGitSourceTree], a [GitSourceTree] on [git]
  /// by default.
  ///
  /// Resolves the packages with [packageResolver], a [PackageResolver] on
  /// [tree] by default, checks them with [engine], and reads baselines with
  /// [baselineFile].
  factory({
    required String root,
    SourceTree? tree,
    GitRunner? git,
    OpenGitSourceTree? openGitSourceTree,
    PackageResolver? packageResolver,
    Engine engine = const Engine(),
    BaselineFile baselineFile = const BaselineFile(),
  }) {
    final resolvedTree = tree ?? FileSystemSourceTree(Directory(root));
    final resolvedGit = git ?? GitRunner(root);
    return Check._(
      root: root,
      tree: resolvedTree,
      git: resolvedGit,
      openGitSourceTree:
          openGitSourceTree ??
          (commit) => GitSourceTree(git: resolvedGit, commit: commit),
      packageResolver:
          packageResolver ??
          PackageResolver.fromTree(root: root, tree: resolvedTree),
      engine: engine,
      baselineFile: baselineFile,
    );
  }

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
    final packages = await _packageResolver(paths);
    final ids = baseline == null
        ? null
        : (await _baselineFile.read(p.join(root, baseline))).ids;
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
    final base = _openGitSourceTree(await _git.mergeBase(ref));
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
