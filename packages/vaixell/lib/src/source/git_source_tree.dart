import 'dart:convert';

import 'package:vaixell/src/git/cat_file_batch.dart';
import 'package:vaixell/src/git/git_runner.dart';
import 'package:vaixell/src/source/source_tree.dart';

/// Returns a [ClosableSourceTree] that reads files at [commit].
typedef OpenGitSourceTree = ClosableSourceTree Function(String commit);

/// A [SourceTree] that holds resources until [close] is called.
abstract interface class ClosableSourceTree implements SourceTree {
  /// Releases the resources used to read files.
  Future<void> close();
}

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
}) implements ClosableSourceTree {
  /// Creates a tree for [commit], using [git] to read it.
  this;

  Future<CatFileBatch>? _batch;

  @override
  Future<List<String>> listFiles(String directory) async {
    final output = await git.run([
      'ls-tree',
      '-r',
      '--name-only',
      '-z',
      commit,
      '--',
      directory,
    ]);
    return [
      for (final path in output.split('\x00'))
        if (path.isNotEmpty) path,
    ]..sort();
  }

  @override
  Future<List<String>> listDirectories(String directory) async {
    final output = await git.run([
      'ls-tree',
      '-d',
      '--name-only',
      '-z',
      commit,
      '--',
      if (directory.isEmpty) '.' else '$directory/',
    ]);
    return [
      for (final path in output.split('\x00'))
        if (path.isNotEmpty) path,
    ]..sort();
  }

  @override
  Future<bool> exists(String path) async => (await _blob(path)) != null;

  @override
  Future<String> read(String path) async {
    final blob = await _blob(path);
    if (blob == null) {
      throw GitException('`$path` is not a file at $commit.');
    }
    return utf8.decode(blob.bytes, allowMalformed: true);
  }

  /// Stops the git process used to read files.
  @override
  Future<void> close() async {
    final batch = _batch;
    if (batch != null) await (await batch).close();
  }

  Future<GitObject?> _blob(String path) async {
    final batch = await (_batch ??= git
        .start(['cat-file', '--batch'])
        .then(CatFileBatch.new));
    final object = await batch.lookup('$commit:./$path');
    return object?.type == 'blob' ? object : null;
  }
}
