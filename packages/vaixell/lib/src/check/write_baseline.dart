import 'package:path/path.dart' as p;
import 'package:vaixell/src/baseline/baseline.dart';
import 'package:vaixell/src/baseline/baseline_file.dart';
import 'package:vaixell/src/check/check.dart';
import 'package:vaixell/src/options/config_exception.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/source/source_tree.dart';

/// {@template write_baseline}
/// Writes the ids of the current violations in a repository to a baseline
/// file.
/// {@endtemplate}
class WriteBaseline({
  /// The repository root directory.
  required final String root,
  required List<RuleEntry> rules,
  SourceTree? tree,
}) {
  /// {@macro write_baseline}
  ///
  /// Checks the packages in [root] like a [Check] with [rules] and [tree].
  ///
  /// Throws an [ArgumentError] when two [rules] share an id, or one is
  /// `parse-error`.
  this;

  final Check _check = Check(root: root, rules: rules, tree: tree);

  /// Checks the packages at [paths], relative to [root], or the discovered
  /// packages when [paths] is empty, and writes their violation ids to the
  /// baseline file at [path], relative to [root].
  ///
  /// Returns the written [Baseline].
  ///
  /// Throws an [ArgumentError] when a path is outside [root], a
  /// [ConfigException] when discovery or a config fails, and a
  /// [BaselineException] when the file can't be written.
  Future<Baseline> call(String path, {List<String> paths = const []}) async {
    final report = await _check(paths: paths);
    final baseline = Baseline(report.violations.map((v) => v.id));
    await BaselineFile(p.join(root, path)).write(baseline);
    return baseline;
  }
}
