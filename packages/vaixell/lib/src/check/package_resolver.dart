import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/config/config_loader.dart';
import 'package:vaixell/src/discovery/package_discovery.dart';
import 'package:vaixell/src/engine/package.dart';
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
  /// reads their configs in [tree].
  factory fromTree({required String root, required SourceTree tree}) =>
      PackageResolver(
        root: root,
        discovery: PackageDiscovery(tree),
        configResolver: ConfigResolver(ConfigLoader(tree)),
      );

  /// Returns the packages at [paths], relative to [root], or the packages
  /// found by [discovery] when [paths] is empty.
  ///
  /// Throws a [ConfigException] when discovery or a config fails.
  Future<List<Package>> call(List<String> paths) async {
    final dirs = paths.isEmpty
        ? await discovery.discover()
        : {for (final path in paths) _relative(path)}.toList();
    final configs = await configResolver.forPackages(dirs);
    return [
      for (final (i, dir) in dirs.indexed)
        Package(path: dir, config: configs[i]),
    ];
  }

  /// Returns [path] relative to [root], in POSIX style, where `''` is the
  /// root itself.
  String _relative(String path) {
    final relative = p.relative(p.join(root, path), from: root);
    return relative == '.' ? '' : p.posix.joinAll(p.split(relative));
  }
}
