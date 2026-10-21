import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/source/source_tree.dart';
import 'package:yaml/yaml.dart';

/// Finds the packages to check in a [SourceTree].
///
/// Packages are directories relative to the root, where `''` is the root:
///
/// 1. When the root `pubspec.yaml` has a `workspace:`, the root and every
///    member.
/// 2. Otherwise, when there's a root `pubspec.yaml`, the root and any
///    `packages/*` or `pkgs/*` directory with a `pubspec.yaml`, as in an
///    app with local packages.
/// 3. Otherwise, every `packages/*`, `pkgs/*` and top-level directory with a
///    `pubspec.yaml`, or the root when there are none.
class PackageDiscovery {
  /// Creates a discovery that reads [tree].
  const new(this.tree);

  /// The tree to search.
  final SourceTree tree;

  static const String _pubspec = 'pubspec.yaml';
  static const List<String> _packageParents = ['packages', 'pkgs'];

  /// Returns the sorted package directories.
  ///
  /// Throws a [ConfigException] when the root `pubspec.yaml` isn't valid
  /// YAML or its `workspace:` is invalid.
  Future<List<String>> discover() async {
    if (await tree.exists(_pubspec)) {
      final members = await _workspaceMembers();
      return {
        '',
        ...?members,
        if (members == null) ...await _packagesIn(_packageParents),
      }.toList()..sort();
    }
    final found = {
      ...await _packagesIn([..._packageParents, '']),
    };
    return found.isEmpty ? [''] : (found.toList()..sort());
  }

  /// Returns the directories under [parents] that have a `pubspec.yaml`.
  Future<List<String>> _packagesIn(List<String> parents) async => [
    for (final parent in parents)
      for (final dir in await tree.listDirectories(parent))
        if (await tree.exists(p.posix.join(dir, _pubspec))) dir,
  ];

  /// Returns the members of the root workspace, or `null` when the root
  /// `pubspec.yaml` has no `workspace:` key.
  Future<List<String>?> _workspaceMembers() async {
    final YamlNode root;
    try {
      root = loadYamlNode(
        await tree.read(_pubspec),
        sourceUrl: Uri.file(_pubspec),
      );
    } on YamlException catch (error) {
      throw ConfigException.yaml(error, path: _pubspec);
    }
    final workspace = root is YamlMap ? root.nodes['workspace'] : null;
    if (workspace == null) return null;
    if (workspace is! YamlList) {
      throw ConfigException.at(
        workspace,
        '`workspace` must be a list of package paths.',
        path: _pubspec,
      );
    }
    return [for (final item in workspace.nodes) await _member(item)];
  }

  Future<String> _member(YamlNode item) async {
    final value = item.value;
    if (value is! String) {
      throw ConfigException.at(
        item,
        '`workspace` must be a list of package paths.',
        path: _pubspec,
      );
    }
    final member = p.posix.normalize(value);
    if (member == '.' ||
        member.startsWith('..') ||
        p.posix.isAbsolute(member)) {
      throw ConfigException.at(
        item,
        'Workspace member `$value` must be a directory inside the workspace.',
        path: _pubspec,
      );
    }
    if (!await tree.exists(p.posix.join(member, _pubspec))) {
      throw ConfigException.at(
        item,
        'Workspace member `$value` has no pubspec.yaml.',
        path: _pubspec,
      );
    }
    return member;
  }
}
