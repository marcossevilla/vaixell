// Keep in sync with packages/vaixell_cli/test/helpers/git_repo.dart. A test
// in vaixell_cli fails when the two differ.

import 'dart:io';

/// The seconds added to the commit date so far, so every commit gets a
/// distinct, increasing date.
var _clock = 0;

/// The environment for git: only what it needs to run, with a fixed
/// identity and no global or system config, so the user's git setup and
/// variables like `GIT_DIR` from a hook can't leak into tests.
Map<String, String> _environment() {
  final date =
      '${DateTime.utc(2000).millisecondsSinceEpoch ~/ 1000 + _clock} '
      '+0000';
  return {
    for (final name in ['PATH', 'HOME', 'USERPROFILE', 'SystemRoot', 'TEMP'])
      name: ?Platform.environment[name],
    'GIT_CONFIG_NOSYSTEM': '1',
    'GIT_CONFIG_GLOBAL': Platform.isWindows ? 'NUL' : '/dev/null',
    'GIT_AUTHOR_NAME': 'Test',
    'GIT_AUTHOR_EMAIL': 'test@example.com',
    'GIT_AUTHOR_DATE': date,
    'GIT_COMMITTER_NAME': 'Test',
    'GIT_COMMITTER_EMAIL': 'test@example.com',
    'GIT_COMMITTER_DATE': date,
  };
}

/// Runs git in [directory] with a fixed identity, no signing and no hooks,
/// and returns stdout.
Future<String> git(String directory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    [
      '-c',
      'commit.gpgsign=false',
      '-c',
      'core.hooksPath=.vaixell-no-hooks',
      ...arguments,
    ],
    workingDirectory: directory,
    environment: _environment(),
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout as String;
}

/// Creates a git repository in [directory] on branch `main`.
Future<void> gitInit(String directory) =>
    git(directory, ['init', '-q', '-b', 'main']);

/// Stages everything in [directory] and commits it with [message].
///
/// Each commit gets a later date than the one before, so sibling commits
/// on different branches get distinct ids even with the same [message].
Future<void> gitCommitAll(String directory, {String message = 'commit'}) async {
  await git(directory, ['add', '-A']);
  _clock++;
  await git(directory, ['commit', '-q', '--allow-empty', '-m', message]);
}
