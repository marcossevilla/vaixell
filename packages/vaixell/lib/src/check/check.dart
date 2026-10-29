import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vaixell/src/baseline/baseline.dart';
import 'package:vaixell/src/check/package_resolver.dart';
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/engine/diff_result.dart';
import 'package:vaixell/src/engine/engine.dart';
import 'package:vaixell/src/report/report.dart';
import 'package:vaixell/src/source/source_tree.dart';

/// {@template check}
/// Checks architecture rules in the packages of a repository.
/// {@endtemplate}
class Check({
  /// The repository root directory.
  required final String root,
  SourceTree? tree,
}) {
  /// {@macro check}
  ///
  /// Reads the files of [root] from [tree], a [FileSystemSourceTree] on
  /// [root] by default.
  this;

  final SourceTree _tree = tree ?? FileSystemSourceTree(Directory(root));

  /// Checks the packages at [paths], relative to [root], or the discovered
  /// packages when [paths] is empty, and returns the [Report].
  ///
  /// With a [baseline] file path, relative to [root], the report is a
  /// [ReportMode.baseline] comparison with its ids. Otherwise it's a
  /// [ReportMode.full] report.
  ///
  /// Throws a [ConfigException] when discovery or a config fails, and a
  /// [BaselineException] when the baseline file is missing or malformed.
  Future<Report> call({List<String> paths = const [], String? baseline}) async {
    final packages = await PackageResolver(root: root, tree: _tree)(paths);
    final ids = baseline == null
        ? null
        : (await BaselineFile(p.join(root, baseline)).read()).ids;
    final violations = await Engine(tree: _tree, packages: packages).run();
    if (ids == null) return Report.full(violations);
    return Report.compared(
      ReportMode.baseline,
      violations,
      DiffResult.compare(base: ids, head: violations),
    );
  }
}
