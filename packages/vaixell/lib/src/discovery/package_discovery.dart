import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/options/config_exception.dart';
import 'package:vaixell/src/source/source_tree.dart';
import 'package:yaml/yaml.dart';

/// A package directory that [PackageDiscovery] found, with its
/// `pubspec.yaml` name.
final class const PackageDir({
  /// The directory, relative to the repository root, in POSIX style, where
  /// `''` is the root itself.
  required final String path,

  /// The `name` in the directory's `pubspec.yaml`, or `null` when the file
  /// is missing or isn't valid, or has no string name.
  final String? name,
}) {
  /// Creates the package directory at [path], named [name].
  this;
}

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

  /// Returns the package directories, sorted by path.
  ///
  /// Throws a [ConfigException] when the root `pubspec.yaml` isn't valid
  /// YAML or its `workspace:` is invalid.
  Future<List<PackageDir>> discover() async {
    if (!await tree.exists(_pubspec)) {
      final found = {
        ...await _packagesIn([..._packageParents, '']),
      };
      final paths = found.isEmpty ? [''] : (found.toList()..sort());
      return [for (final path in paths) await at(path)];
    }
    final pubspec = (await tree.read(_pubspec)).parseYaml(path: _pubspec);
    final members = await _workspaceMembers(pubspec);
    final paths = {
      ...?members,
      if (members == null) ...await _packagesIn(_packageParents),
    }.toList()..sort();
    return [
      PackageDir(path: '', name: _name(pubspec.value)),
      for (final path in paths) await at(path),
    ];
  }

  /// Returns the package directory at [path], relative to the root in POSIX
  /// style, with the name in its `pubspec.yaml`.
  Future<PackageDir> at(String path) async {
    final pubspec = p.posix.join(path, _pubspec);
    if (!await tree.exists(pubspec)) return PackageDir(path: path);
    try {
      return PackageDir(
        path: path,
        name: _name(loadYaml(await tree.read(pubspec))),
      );
    } on YamlException {
      return PackageDir(path: path);
    }
  }

  /// The string `name` in the parsed [pubspec], or `null`.
  String? _name(Object? pubspec) => switch (pubspec) {
    {'name': final String name} => name,
    _ => null,
  };

  /// Returns the directories under [parents] that have a `pubspec.yaml`.
  Future<List<String>> _packagesIn(List<String> parents) async => [
    for (final parent in parents)
      for (final dir in await tree.listDirectories(parent))
        if (await tree.exists(p.posix.join(dir, _pubspec))) dir,
  ];

  /// Returns the members of the workspace in the root [pubspec], or `null`
  /// when it has no `workspace:` key.
  Future<List<String>?> _workspaceMembers(YamlNode pubspec) async {
    final workspace = pubspec is YamlMap ? pubspec.nodes['workspace'] : null;
    if (workspace == null) return null;
    if (workspace is! YamlList) {
      throw workspace.configError(
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
      throw item.configError(
        '`workspace` must be a list of package paths.',
        path: _pubspec,
      );
    }
    final member = p.posix.normalize(value);
    if (member == '.' ||
        member.startsWith('..') ||
        p.posix.isAbsolute(member)) {
      throw item.configError(
        'Workspace member `$value` must be a directory inside the workspace.',
        path: _pubspec,
      );
    }
    final Glob glob;
    try {
      glob = Glob(member, context: p.posix);
    } on FormatException catch (error) {
      throw item.configError(
        'Workspace member `$value` is not a valid glob: ${error.message}',
        path: _pubspec,
      );
    }
    final matches = await _matching(glob);
    if (matches.isEmpty) {
      throw item.configError(
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
