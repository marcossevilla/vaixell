import 'dart:convert';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/src/git/git_runner.dart';

import '../../helpers/git_repo.dart';

/// An executable that isn't on any `PATH`.
const _missingGit = 'vaixell-test-missing-git';

Matcher _gitError(Object message, {bool unavailable = false}) => throwsA(
  isA<GitException>()
      .having((e) => e.toString(), 'toString()', message)
      .having((e) => e.unavailable, 'unavailable', unavailable),
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
      await gitInit(d.sandbox);
      await d.dir('sub').create();
      final sub = GitRunner('${d.sandbox}/sub');
      expect(await sub.run(['rev-parse', '--show-prefix']), equals('sub/\n'));
    });

    test('decodes stdout as UTF-8', () async {
      await gitInit(d.sandbox);
      await d.file('café.dart').create();
      await gitCommitAll(d.sandbox);
      final output = await runner.run(['ls-tree', '--name-only', '-z', 'HEAD']);
      expect(output.split('\x00'), contains('café.dart'));
    });

    group('without git', () {
      late GitRunner missing;

      setUp(() => missing = GitRunner(d.sandbox, executable: _missingGit));

      test('run throws a $GitException', () async {
        await expectLater(
          missing.run(['--version']),
          _gitError(startsWith('Could not run `git`: '), unavailable: true),
        );
      });

      test('start throws a $GitException', () async {
        await expectLater(
          missing.start(['--version']),
          _gitError(startsWith('Could not run `git`: '), unavailable: true),
        );
      });

      test('mergeBase throws a $GitException', () async {
        await expectLater(
          missing.mergeBase('main'),
          _gitError(startsWith('Could not run `git`: '), unavailable: true),
        );
      });
    });

    test('starts git in the working directory', () async {
      await gitInit(d.sandbox);
      await d.dir('sub').create();
      final process = await GitRunner('${d.sandbox}/sub')
          .start(['rev-parse', '--show-prefix']);
      final output = await process.stdout.transform(utf8.decoder).join();
      expect(await process.exitCode, equals(0));
      expect(output, equals('sub/\n'));
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
        await gitCommitAll(d.sandbox, message: 'other');
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
        await gitCommitAll(d.sandbox, message: 'feature');
        await git(d.sandbox, ['checkout', '-q', 'main']);
        await gitCommitAll(d.sandbox, message: 'main');
        await git(d.sandbox, ['checkout', '-q', 'feature']);
        expect(await runner.mergeBase('main'), equals(fork));
      });
    });
  });
}
