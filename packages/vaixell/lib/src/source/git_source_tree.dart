import 'dart:convert';

import 'package:vaixell/src/git/cat_file_batch.dart';
import 'package:vaixell/src/git/git_runner.dart';
import 'package:vaixell/src/source/source_tree.dart';

/// A [SourceTree] that reads files at a git commit.
///
/// Paths are relative to the runner's working directory, so a package in a
/// subdirectory of the repository sees the same paths as on disk. Nothing
/// is checked out. Call [close] when done.
class GitSourceTree({
  /// The runner used to read the repository.
  required final GitRunner git,

  /// The commit to read.
  required final String commit,
}) implements SourceTree {
  /// Creates a tree for [commit], using [git] to read it.
  this;

  Future<CatFileBatch>? _batch;

  @override
  Future<List<String>> listFiles(String directory) =>
      _lsTree(['-r'], directory.isEmpty ? '.' : directory);

  @override
  Future<List<String>> listDirectories(String directory) =>
      _lsTree(['-d'], directory.isEmpty ? '.' : '$directory/');

  @override
  Future<bool> exists(String path) async => (await _blob(path)) != null;

  @override
  Future<String> read(String path) async {
    final blob = await _blob(path);
    if (blob == null) {
      throw GitException('`$path` is not a file at $commit.');
    }
    return utf8.decode(blob, allowMalformed: true);
  }

  /// Stops the git process used to read files.
  Future<void> close() async {
    final batch = await _batch;
    await batch?.close();
  }

  Future<List<int>?> _blob(String path) async {
    final batch = await (_batch ??= git
        .start(['cat-file', '--batch'])
        .then(CatFileBatch.new));
    return await batch.blob('$commit:./$path');
  }

  /// Returns the sorted paths that `git ls-tree` with [flags] lists for
  /// [pathspec] at [commit].
  Future<List<String>> _lsTree(List<String> flags, String pathspec) async {
    final output = await git.run([
      'ls-tree',
      ...flags,
      '--name-only',
      '-z',
      commit,
      '--',
      pathspec,
    ]);
    return [
      for (final path in output.split('\x00'))
        if (path.isNotEmpty) path,
    ]..sort();
  }
}
