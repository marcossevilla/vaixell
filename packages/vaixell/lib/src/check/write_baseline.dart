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
class WriteBaseline({
  /// The repository root directory.
  required final String root,
  SourceTree? tree,
}) {
  /// {@macro write_baseline}
  ///
  /// Reads the files of [root] from [tree], a [FileSystemSourceTree] on
  /// [root] by default.
  this;

  final SourceTree _tree = tree ?? FileSystemSourceTree(Directory(root));

  /// Checks the packages at [paths], relative to [root], or the discovered
  /// packages when [paths] is empty, and writes their violation ids to the
  /// baseline file at [path], relative to [root].
  ///
  /// Returns the written [Baseline].
  ///
  /// Throws a [ConfigException] when discovery or a config fails.
  Future<Baseline> call(String path, {List<String> paths = const []}) async {
    final packages = await PackageResolver(root: root, tree: _tree)(paths);
    final violations = await const Engine().run(
      tree: _tree,
      packages: packages,
    );
    final baseline = Baseline(violations.map((v) => v.id));
    await BaselineFile(p.join(root, path)).write(baseline);
    return baseline;
  }
}
