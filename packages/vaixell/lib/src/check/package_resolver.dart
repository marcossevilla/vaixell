import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/config/config_loader.dart';
import 'package:vaixell/src/discovery/package_discovery.dart';
import 'package:vaixell/src/engine/package.dart';
import 'package:vaixell/src/options/config_exception.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/source/source_tree.dart';

/// Resolves the packages to check in a repository, each with its nearest
/// config.
class PackageResolver({
  /// The repository root directory.
  required final String root,
  required SourceTree tree,
  required List<RuleEntry> rules,
}) {
  /// Creates a resolver for the packages in [root] that discovers them and
  /// reads their configs in [tree], which configure [rules].
  ///
  /// Throws an [ArgumentError] when two [rules] share an id, or one is
  /// `parse-error`.
  this;

  final PackageDiscovery _discovery = PackageDiscovery(tree);
  final ConfigResolver _configResolver = ConfigResolver(
    ConfigLoader(tree, RuleSet(rules)),
  );

  /// Returns the packages at [paths], relative to [root], or the discovered
  /// packages when [paths] is empty, each with the name in its
  /// `pubspec.yaml`.
  ///
  /// Throws an [ArgumentError] when a path is outside [root], and a
  /// [ConfigException] when discovery or a config fails.
  Future<List<Package>> call(List<String> paths) async {
    final dirs = paths.isEmpty
        ? await _discovery.discover()
        : [
            for (final path in {for (final path in paths) _relative(path)})
              await _discovery.at(path),
          ];
    final configs = await _configResolver.forPackages([
      for (final dir in dirs) dir.path,
    ]);
    return [
      for (final dir in dirs)
        Package(path: dir.path, config: configs[dir.path]!, name: dir.name),
    ];
  }

  /// Returns [path] relative to [root], in POSIX style, where `''` is the
  /// root itself.
  ///
  /// Throws an [ArgumentError] when [path] is outside [root].
  String _relative(String path) {
    final full = p.normalize(p.join(root, path));
    if (!p.equals(full, root) && !p.isWithin(root, full)) {
      throw ArgumentError.value(path, 'paths', 'Is outside `$root`');
    }
    return p.posix.joinAll(p.split(p.relative(full, from: root))).asTreePath;
  }
}
