import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/source/source_tree.dart';
import 'package:yaml/yaml.dart';

/// Finds the packages to check in a [SourceTree].
///
/// Packages are directories relative to the root, where `''` is the root:
///
/// 1. When the root `pubspec.yaml` has a `workspace:`, the root and every
///    member. Members are globs, as in pub, so `packages/*` matches every
///    directory in `packages` with a `pubspec.yaml`.
/// 2. Otherwise, when there's a root `pubspec.yaml`, the root and any
///    `packages/*` or `pkgs/*` directory with a `pubspec.yaml`, as in an
///    app with local packages.
/// 3. Otherwise, every `packages/*`, `pkgs/*` and top-level directory with a
///    `pubspec.yaml`, or the root when there are none.
class const PackageDiscovery(
  /// The tree to search.
  final SourceTree tree,
) {
  /// Creates a discovery that reads [tree].
  this;

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
    return [for (final item in workspace.nodes) ...await _members(item)];
  }

  /// Returns the package directories that the workspace member [item]
  /// matches.
  Future<List<String>> _members(YamlNode item) async {
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
    final Glob glob;
    try {
      glob = Glob(member, context: p.posix);
    } on FormatException catch (error) {
      throw ConfigException.at(
        item,
        'Workspace member `$value` is not a valid glob: ${error.message}',
        path: _pubspec,
      );
    }
    final matches = await _matching(glob);
    if (matches.isEmpty) {
      throw ConfigException.at(
        item,
        Glob.quote(member) == member
            ? 'Workspace member `$value` has no pubspec.yaml.'
            : 'Workspace member `$value` matches no directory with a '
                  'pubspec.yaml.',
        path: _pubspec,
      );
    }
    return matches;
  }

  /// Returns the directories that match [glob] and have a `pubspec.yaml`.
  ///
  /// Only lists the files under the leading segments of [glob] without
  /// wildcards.
  Future<List<String>> _matching(Glob glob) async {
    final segments = p.posix.split(glob.pattern);
    final literal = segments.takeWhile((s) => Glob.quote(s) == s).toList();
    if (literal.length == segments.length) {
      final dir = glob.pattern;
      return [if (await tree.exists(p.posix.join(dir, _pubspec))) dir];
    }
    return [
      for (final path in await tree.listFiles(p.posix.joinAll(literal)))
        if (p.posix.basename(path) == _pubspec &&
            p.posix.dirname(path) != '.' &&
            glob.matches(p.posix.dirname(path)))
          p.posix.dirname(path),
    ];
  }
}
