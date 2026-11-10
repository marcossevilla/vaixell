import 'dart:convert';
import 'dart:io';

/// A git command that failed, or a repository in an unusable state.
class const GitException(
  /// A description of the problem.
  final String message, {

  /// Whether git itself couldn't run, as opposed to a git command failing.
  final bool unavailable = false,
}) implements Exception {
  /// Creates an exception with a [message] for the user, where git couldn't
  /// run when [unavailable].
  this;

  @override
  String toString() => message;
}

/// Runs git commands in a directory.
///
/// Output is decoded as UTF-8, so paths from `ls-tree -z` stay intact on
/// every platform.
class const GitRunner(
  /// The directory git runs in.
  ///
  /// Relative paths are resolved against it.
  final String workingDirectory, {

  /// The git executable, looked up on the `PATH` unless it's a path.
  final String executable = 'git',
}) {
  /// Creates a runner for the repository that contains [workingDirectory].
  this;

  /// Runs `git` with [arguments] and returns its stdout.
  ///
  /// Throws a [GitException] if git can't start or exits with an error.
  Future<String> run(List<String> arguments) async {
    final result = await _run(arguments);
    if (result.exitCode == 0) return result.stdout as String;
    final stderr = (result.stderr as String).trim();
    throw GitException('`git ${arguments.join(' ')}` failed: $stderr');
  }

  /// Starts a long-running `git` process with [arguments].
  ///
  /// Throws a [GitException] if git can't start.
  Future<Process> start(List<String> arguments) async {
    try {
      return await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
      );
    } on ProcessException catch (error) {
      throw GitException(
        'Could not run `git`: ${error.message}',
        unavailable: true,
      );
    }
  }

  /// Returns the commit where [ref] and `HEAD` diverged.
  ///
  /// Throws a [GitException] with a message for the user when
  /// [workingDirectory] isn't in a git repository, [ref] can't be found, or
  /// [ref] and `HEAD` have no common ancestor.
  Future<String> mergeBase(String ref) async {
    if ((await _run(['rev-parse', '--git-dir'])).exitCode != 0) {
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
      final base = await run(['merge-base', commit.trim(), 'HEAD']);
      return base.trim();
    } on GitException {
      throw GitException('`$ref` and HEAD have no common ancestor.');
    }
  }

  /// Runs `git` with [arguments] and returns its result, whatever its exit
  /// code.
  ///
  /// Throws a [GitException] if git can't start.
  Future<ProcessResult> _run(List<String> arguments) async {
    try {
      return await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } on ProcessException catch (error) {
      throw GitException(
        'Could not run `git`: ${error.message}',
        unavailable: true,
      );
    }
  }
}
