import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:theseus_cli/theseus_cli.dart';

import '../helpers/git_repo.dart';

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

    test('throws when git can not start', () async {
      final missing = GitRunner(d.sandbox, executable: 'no-such-git');
      await expectLater(
        missing.run(['--version']),
        _gitError(startsWith('Could not run `no-such-git`: ')),
      );
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
