import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vaixell/src/baseline/baseline.dart';
import 'package:vaixell/src/check/package_resolver.dart';
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/engine/engine.dart';
import 'package:vaixell/src/source/source_tree.dart';

/// {@template write_baseline}
/// Writes the ids of the current violations in a repository to a baseline
/// file.
/// {@endtemplate}
class const WriteBaseline._({
  /// The repository root directory.
  required final String root,
  required final SourceTree _tree,
  required final PackageResolver _packageResolver,
  required final Engine _engine,
  required final BaselineFile _baselineFile,
}) {
  /// {@macro write_baseline}
  ///
  /// Reads the files of [root] from [tree], a [FileSystemSourceTree] on
  /// [root] by default.
  ///
  /// Resolves the packages with [packageResolver], a [PackageResolver] on
  /// [tree] by default, checks them with [engine], and writes the baseline
  /// with [baselineFile].
  factory({
    required String root,
    SourceTree? tree,
    PackageResolver? packageResolver,
    Engine engine = const Engine(),
    BaselineFile baselineFile = const BaselineFile(),
  }) {
    final resolvedTree = tree ?? FileSystemSourceTree(Directory(root));
    return WriteBaseline._(
      root: root,
      tree: resolvedTree,
      packageResolver:
          packageResolver ??
          PackageResolver.fromTree(root: root, tree: resolvedTree),
      engine: engine,
      baselineFile: baselineFile,
    );
  }

  /// Checks the packages at [paths], relative to [root], or the discovered
  /// packages when [paths] is empty, and writes their violation ids to the
  /// baseline file at [path], relative to [root].
  ///
  /// Returns the written [Baseline].
  ///
  /// Throws a [ConfigException] when discovery or a config fails.
  Future<Baseline> call(String path, {List<String> paths = const []}) async {
    final packages = await _packageResolver(paths);
    final violations = await _engine.run(tree: _tree, packages: packages);
    final baseline = Baseline(violations.map((v) => v.id));
    await _baselineFile.write(p.join(root, path), baseline);
    return baseline;
  }
}
