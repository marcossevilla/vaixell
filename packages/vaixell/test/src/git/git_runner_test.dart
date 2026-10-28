import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

import '../../helpers/git_repo.dart';

Matcher _gitError(Object message) => throwsA(
  isA<GitException>().having((e) => e.toString(), 'toString()', message),
);

void main() {
  group(GitRunner, () {
    late GitRunner runner;

    setUp(() => runner = GitRunner(d.sandbox));

    test('returns stdout', () async {
      expect(await runner.run(['--version']), startsWith('git version'));
    });

    test('throws with stderr when git fails', () async {
      await expectLater(
        runner.run(['rev-parse', 'HEAD']),
        _gitError(startsWith('`git rev-parse HEAD` failed: fatal: ')),
      );
    });

    test('runs git in the working directory', () async {
      List<String>? arguments;
      String? directory;
      final fake = GitRunner(
        d.sandbox,
        runGit: (args, {throwOnError = true, processWorkingDir}) async {
          expect(throwOnError, isFalse);
          arguments = args;
          directory = processWorkingDir;
          return ProcessResult(0, 0, 'out', '');
        },
      );
      expect(await fake.run(['status']), equals('out'));
      expect(arguments, equals(['status']));
      expect(directory, equals(d.sandbox));
    });

    for (final exitCode in [127, 9009]) {
      test('throws when the shell can not find git ($exitCode)', () async {
        final missing = GitRunner(
          d.sandbox,
          runGit: (_, {throwOnError = true, processWorkingDir}) async =>
              ProcessResult(0, exitCode, '', 'git: command not found\n'),
        );
        await expectLater(
          missing.run(['--version']),
          _gitError('Could not run `git`: git: command not found'),
        );
      });
    }

    test('throws when git can not start', () async {
      final missing = GitRunner(
        d.sandbox,
        runGit: (args, {throwOnError = true, processWorkingDir}) =>
            throw ProcessException('git', args, 'No such file'),
      );
      await expectLater(
        missing.run(['--version']),
        _gitError('Could not run `git`: No such file'),
      );
    });

    test('starts git through startProcess', () async {
      String? executable;
      String? directory;
      final fake = GitRunner(
        d.sandbox,
        startProcess: (exe, args, {workingDirectory}) {
          executable = exe;
          directory = workingDirectory;
          return Process.start('git', args);
        },
      );
      await (await fake.start(['--version'])).exitCode;
      expect(executable, equals('git'));
      expect(directory, equals(d.sandbox));
    });

    group('mergeBase', () {
      test('fails outside a git repository', () async {
        await expectLater(
          runner.mergeBase('main'),
          _gitError('`${d.sandbox}` is not in a git repository.'),
        );
      });

      test('fails for an unknown ref', () async {
        await gitInit(d.sandbox);
        await gitCommitAll(d.sandbox);
        await expectLater(
          runner.mergeBase('origin/main'),
          _gitError(
            'Could not find the git ref `origin/main`. In a shallow clone, '
            'fetch it first.',
          ),
        );
      });

      test('treats refs as refs, not options', () async {
        await gitInit(d.sandbox);
        await gitCommitAll(d.sandbox);
        await expectLater(
          runner.mergeBase('--all'),
          _gitError(startsWith('Could not find the git ref `--all`.')),
        );
      });

      test('fails without a common ancestor', () async {
        await gitInit(d.sandbox);
        await gitCommitAll(d.sandbox);
        await git(d.sandbox, ['checkout', '-q', '--orphan', 'other']);
        await gitCommitAll(d.sandbox);
        await expectLater(
          runner.mergeBase('main'),
          _gitError('`main` and HEAD have no common ancestor.'),
        );
      });

      test('returns the commit where the branches diverged', () async {
        await gitInit(d.sandbox);
        await gitCommitAll(d.sandbox);
        final fork = (await git(d.sandbox, ['rev-parse', 'HEAD'])).trim();
        await git(d.sandbox, ['checkout', '-q', '-b', 'feature']);
        await gitCommitAll(d.sandbox);
        await git(d.sandbox, ['checkout', '-q', 'main']);
        await gitCommitAll(d.sandbox);
        await git(d.sandbox, ['checkout', '-q', 'feature']);
        expect(await runner.mergeBase('main'), equals(fork));
      });
    });
  });
}
