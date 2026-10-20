import 'dart:convert';

import 'package:theseus_cli/src/git/cat_file_batch.dart';
import 'package:theseus_cli/src/git/git_runner.dart';
import 'package:theseus_cli/src/source/source_tree.dart';

/// A [SourceTree] that reads files at a git commit.
///
/// Paths are relative to the runner's working directory, so a package in a
/// subdirectory of the repository sees the same paths as on disk. Nothing
/// is checked out. Call [close] when done.
class GitSourceTree implements SourceTree {
  /// Creates a tree for [commit], using [git] to read it.
  new({required this.git, required this.commit});

  /// The runner used to read the repository.
  final GitRunner git;

  /// The commit to read.
  final String commit;

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
