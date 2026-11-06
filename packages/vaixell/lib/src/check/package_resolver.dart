import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/config/config_loader.dart';
import 'package:vaixell/src/discovery/package_discovery.dart';
import 'package:vaixell/src/engine/package.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/source/source_tree.dart';

/// Resolves the packages to check in a repository, each with its nearest
/// config.
class const PackageResolver({
  /// The repository root directory.
  required final String root,

  /// Finds the packages when no paths are given.
  required final PackageDiscovery discovery,

  /// Finds the config of each package.
  required final ConfigResolver configResolver,
}) {
  /// Creates a resolver for the packages in [root] that finds them with
  /// [discovery] and their configs with [configResolver].
  this;

  /// Creates a resolver for the packages in [root] that discovers them and
  /// reads their configs in [tree], which configure [rules].
  ///
  /// Throws an [ArgumentError] when two [rules] share an id, or one is
  /// `parse-error`.
  factory fromTree({
    required String root,
    required SourceTree tree,
    required List<RuleEntry> rules,
  }) => PackageResolver(
    root: root,
    discovery: PackageDiscovery(tree),
    configResolver: ConfigResolver(ConfigLoader(tree, RuleSet(rules))),
  );

  /// Returns the packages at [paths], relative to [root], or the packages
  /// found by [discovery] when [paths] is empty, each with the name in its
  /// `pubspec.yaml`.
  ///
  /// Throws a [ConfigException] when discovery or a config fails.
  Future<List<Package>> call(List<String> paths) async {
    final dirs = paths.isEmpty
        ? await discovery.discover()
        : [
            for (final path in {for (final path in paths) _relative(path)})
              await discovery.at(path),
          ];
    final configs = await configResolver.forPackages([
      for (final dir in dirs) dir.path,
    ]);
    return [
      for (final (i, dir) in dirs.indexed)
        Package(path: dir.path, config: configs[i], name: dir.name),
    ];
  }

  /// Returns [path] relative to [root], in POSIX style, where `''` is the
  /// root itself.
  String _relative(String path) {
    final relative = p.relative(p.join(root, path), from: root);
    return relative == '.' ? '' : p.posix.joinAll(p.split(relative));
  }
}
