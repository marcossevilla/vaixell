import 'dart:convert';
import 'dart:io';

/// A git command that failed, or a repository in an unusable state.
class GitException implements Exception {
  /// Creates an exception with a [message] for the user.
  const new(this.message);

  /// A description of the problem.
  final String message;

  @override
  String toString() => message;
}

/// Runs git commands in a directory.
class GitRunner {
  /// Creates a runner for the repository that contains [workingDirectory].
  ///
  /// [executable] is the git binary to run.
  const new(this.workingDirectory, {this.executable = 'git'});

  /// The directory git runs in. Relative paths are resolved against it.
  final String workingDirectory;

  /// The git binary to run.
  final String executable;

  /// Runs `git` with [arguments] and returns its stdout.
  ///
  /// Throws a [GitException] if git can't start or exits with an error.
  Future<String> run(List<String> arguments) async {
    final ProcessResult result;
    try {
      result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } on ProcessException catch (error) {
      throw GitException('Could not run `$executable`: ${error.message}');
    }
    if (result.exitCode != 0) {
      throw GitException(
        '`git ${arguments.join(' ')}` failed: '
        '${(result.stderr as String).trim()}',
      );
    }
    return result.stdout as String;
  }

  /// Starts a long-running `git` process with [arguments].
  Future<Process> start(List<String> arguments) =>
      Process.start(executable, arguments, workingDirectory: workingDirectory);

  /// Returns the commit where [ref] and `HEAD` diverged.
  ///
  /// Throws a [GitException] with a message for the user when
  /// [workingDirectory] isn't in a git repository, [ref] can't be found, or
  /// [ref] and `HEAD` have no common ancestor.
  Future<String> mergeBase(String ref) async {
    try {
      await run(['rev-parse', '--is-inside-work-tree']);
    } on GitException {
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
