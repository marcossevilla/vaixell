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

  /// The files of [root].
  required final SourceTree tree,
}) {
  /// Creates a resolver for the packages of [tree], rooted at [root].
  this;

  /// Returns the packages at [paths], relative to [root], or the packages
  /// found by [PackageDiscovery] when [paths] is empty.
  ///
  /// Throws a [ConfigException] when discovery or a config fails.
  Future<List<Package>> call(List<String> paths) async {
    final dirs = paths.isEmpty
        ? await PackageDiscovery(tree).discover()
        : {for (final path in paths) _relative(path)}.toList();
    final resolver = ConfigResolver(tree);
    return [
      for (final dir in dirs)
        Package(path: dir, config: await resolver.forPackage(dir)),
    ];
  }

  /// Returns [path] relative to [root], in POSIX style, where `''` is the
  /// root itself.
  String _relative(String path) {
    final relative = p.relative(p.join(root, path), from: root);
    return relative == '.' ? '' : p.posix.joinAll(p.split(relative));
  }
}
