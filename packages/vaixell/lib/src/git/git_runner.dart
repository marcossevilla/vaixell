import 'dart:io';

import 'package:git/git.dart' as git show runGit;
import 'package:git/git.dart' show GitDir;

/// A git command that failed, or a repository in an unusable state.
class const GitException(
  /// A description of the problem.
  final String message,
) implements Exception {
  /// Creates an exception with a [message] for the user.
  this;

  @override
  String toString() => message;
}

/// Runs `git` with [arguments] in [processWorkingDir] and returns its result.
///
/// Matches the signature of `runGit` from `package:git`.
typedef RunGit = Future<ProcessResult> Function(
  List<String> arguments, {
  bool throwOnError,
  String? processWorkingDir,
});

/// Starts [executable] with [arguments] in [workingDirectory].
///
/// Matches the signature of [Process.start].
typedef StartProcess = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

/// Runs git commands in a directory.
///
/// [run] goes through `package:git`, which decodes output with
/// [SystemEncoding]. That is UTF-8 on Linux and macOS, so paths from
/// `ls-tree -z` stay intact. On Windows it is the system code page, and
/// non-ASCII paths are not supported there.
class const GitRunner(
  /// The directory git runs in.
  ///
  /// Relative paths are resolved against it.
  final String workingDirectory, {

  /// Runs git for [run]. Defaults to `package:git`'s `runGit`.
  final RunGit runGit = git.runGit,

  /// Starts git for [start]. Defaults to [Process.start].
  final StartProcess startProcess = Process.start,
}) {
  /// Creates a runner for the repository that contains [workingDirectory].
  this;

  /// Runs `git` with [arguments] and returns its stdout.
  ///
  /// Throws a [GitException] if git can't start or exits with an error.
  Future<String> run(List<String> arguments) async {
    final ProcessResult result;
    try {
      result = await runGit(
        arguments,
        throwOnError: false,
        processWorkingDir: workingDirectory,
      );
    } on ProcessException catch (error) {
      throw GitException('Could not run `git`: ${error.message}');
    }
    final stderr = (result.stderr as String).trim();
    switch (result.exitCode) {
      case 0:
        return result.stdout as String;
      // `package:git` runs git in a shell, which exits with 127 (9009 on
      // Windows) when it can't find git.
      case 127 || 9009:
        throw GitException('Could not run `git`: $stderr');
      case _:
        throw GitException('`git ${arguments.join(' ')}` failed: $stderr');
    }
  }

  /// Starts a long-running `git` process with [arguments].
  Future<Process> start(List<String> arguments) =>
      startProcess('git', arguments, workingDirectory: workingDirectory);

  /// Returns the commit where [ref] and `HEAD` diverged.
  ///
  /// Throws a [GitException] with a message for the user when
  /// [workingDirectory] isn't in a git repository, [ref] can't be found, or
  /// [ref] and `HEAD` have no common ancestor.
  Future<String> mergeBase(String ref) async {
    if (!await GitDir.isGitDir(workingDirectory)) {
      throw GitException('`$workingDirectory` is not in a git repository.');
    }
    final String commit;
    try {
      commit = await run([
        'rev-parse',
        '--verify',
        '--quiet',
        '--end-of-options',
        '$ref^{commit}',
      ]);
    } on GitException {
      throw GitException(
        'Could not find the git ref `$ref`. In a shallow clone, fetch it '
        'first.',
      );
    }
    try {
      return (await run(['merge-base', commit.trim(), 'HEAD'])).trim();
    } on GitException {
      throw GitException('`$ref` and HEAD have no common ancestor.');
    }
  }
}
