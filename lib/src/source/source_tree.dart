import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A read-only view of the files in a repository.
///
/// Paths are POSIX-style and relative to the root of the tree, for example
/// `lib/src/foo.dart`.
abstract interface class SourceTree {
  /// Returns the sorted paths of every file under [directory], recursively.
  ///
  /// Returns an empty list when [directory] doesn't exist.
  Future<List<String>> listFiles(String directory);

  /// Returns the sorted paths of the immediate subdirectories of
  /// [directory], where `''` is the root.
  ///
  /// Returns an empty list when [directory] doesn't exist.
  Future<List<String>> listDirectories(String directory);

  /// Whether a file exists at [path].
  Future<bool> exists(String path);

  /// Returns the contents of the file at [path], decoded as UTF-8.
  Future<String> read(String path);
}

/// A [SourceTree] backed by a directory on the local file system.
class FileSystemSourceTree implements SourceTree {
  /// Creates a tree rooted at [root].
  new(this.root);

  /// The root directory of the tree.
  final Directory root;

  @override
  Future<List<String>> listFiles(String directory) async {
    final dir = Directory(p.join(root.path, directory));
    if (!dir.existsSync()) return const [];
    final paths = [
      await for (final entity in dir.list(recursive: true, followLinks: false))
        if (entity is File)
          p.posix.joinAll(p.split(p.relative(entity.path, from: root.path))),
    ]..sort();
    return paths;
  }

  @override
  Future<List<String>> listDirectories(String directory) async {
    final dir = Directory(p.join(root.path, directory));
    if (!dir.existsSync()) return const [];
    final paths = [
      await for (final entity in dir.list(followLinks: false))
        if (entity is Directory)
          p.posix.joinAll(p.split(p.relative(entity.path, from: root.path))),
    ]..sort();
    return paths;
  }

  @override
  Future<bool> exists(String path) async =>
      File(p.join(root.path, path)).existsSync();

  @override
  Future<String> read(String path) async {
    final bytes = await File(p.join(root.path, path)).readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }
}
