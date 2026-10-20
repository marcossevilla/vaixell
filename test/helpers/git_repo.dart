import 'dart:io';

/// Runs git in [directory] with a fixed identity and no signing, and
/// returns stdout.
Future<String> git(String directory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    [
      '-c',
      'commit.gpgsign=false',
      '-c',
      'core.hooksPath=/dev/null',
      ...arguments,
    ],
    workingDirectory: directory,
    environment: {
      'GIT_AUTHOR_NAME': 'Test',
      'GIT_AUTHOR_EMAIL': 'test@example.com',
      'GIT_COMMITTER_NAME': 'Test',
      'GIT_COMMITTER_EMAIL': 'test@example.com',
    },
  );
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout as String;
}

/// Creates a git repository in [directory] on branch `main`.
Future<void> gitInit(String directory) =>
    git(directory, ['init', '-q', '-b', 'main']);

var _commits = 0;

/// Stages everything in [directory] and commits it.
///
/// Every commit gets a unique message, so commits made in the same second
/// with the same tree still get different ids.
Future<void> gitCommitAll(String directory) async {
  await git(directory, ['add', '-A']);
  await git(directory, [
    'commit',
    '-q',
    '--allow-empty',
    '-m',
    'c${_commits++}',
  ]);
}
