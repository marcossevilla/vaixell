import 'dart:io';

import 'package:io/io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:theseus_cli/theseus_cli.dart';

import '../helpers/git_repo.dart';

void main() {
  group('--git-diff', () {
    late StringBuffer out;
    late StringBuffer err;

    Future<int> run(List<String> arguments, {String? root}) => TheseusCommand(
      stdout: out,
      stderr: err,
      root: Directory(root ?? d.sandbox),
    ).run(arguments);

    Future<void> writeLib(Map<String, String> files) => d.dir('lib', [
      for (final MapEntry(:key, :value) in files.entries) d.file(key, value),
    ]).create();

    setUp(() async {
      out = StringBuffer();
      err = StringBuffer();
      await gitInit(d.sandbox);
      await writeLib({'a.dart': 'void old() {}\nvoid kept() {}\n'});
      await gitCommitAll(d.sandbox);
      await git(d.sandbox, ['checkout', '-q', '-b', 'feature']);
    });

    test('reports added and fixed violations and exits 1', () async {
      await File(d.path('lib/a.dart'))
          .writeAsString('// Moved down.\nvoid kept() {}\nvoid added() {}\n');
      await gitCommitAll(d.sandbox);

      expect(await run(['--git-diff=main']), equals(1));
      expect(
        out.toString(),
        equals(
          'lib/a.dart:3:6: error: Top-level function `added` is not allowed. '
          'Move it into a class. [top-level-function:lib/a.dart:added]\n'
          'Fixed: top-level-function:lib/a.dart:old\n'
          '1 new violation, 1 fixed.\n',
        ),
      );
      expect(err.toString(), isEmpty);
    });

    test('exits 0 when violations are only fixed', () async {
      await writeLib({'a.dart': 'void kept() {}\n'});
      await gitCommitAll(d.sandbox);

      expect(await run(['--git-diff=main']), equals(ExitCode.success.code));
      expect(out.toString(), endsWith('0 new violations, 1 fixed.\n'));
    });

    test('compares against the merge-base, not the tip of the ref', () async {
      await git(d.sandbox, ['checkout', '-q', 'main']);
      await writeLib({'a.dart': 'void old() {}\nvoid kept() {}\n'});
      await writeLib({'b.dart': 'void onMain() {}\n'});
      await gitCommitAll(d.sandbox);
      await git(d.sandbox, ['checkout', '-q', 'feature']);

      expect(await run(['--git-diff=main']), equals(ExitCode.success.code));
      expect(out.toString(), equals('0 new violations, 0 fixed.\n'));
    });

    test('counts uncommitted and untracked changes as head', () async {
      await writeLib({'b.dart': 'void untracked() {}\n'});

      expect(await run(['--git-diff=main']), equals(1));
      expect(
        out.toString(),
        contains('[top-level-function:lib/b.dart:untracked]'),
      );
    });

    test('uses the head config for both sides', () async {
      await d
          .file(
            'analysis_options.yaml',
            'theseus:\n  rules:\n    top-level-function: off\n',
          )
          .create();

      expect(await run(['--git-diff=main']), equals(ExitCode.success.code));
      expect(out.toString(), equals('0 new violations, 0 fixed.\n'));
    });

    test('only new errors fail the run', () async {
      await d
          .file(
            'analysis_options.yaml',
            'theseus:\n  rules:\n    top-level-function: warning\n',
          )
          .create();
      await writeLib({'b.dart': 'void added() {}\n'});

      expect(await run(['--git-diff=main']), equals(ExitCode.success.code));
      expect(out.toString(), contains('warning: '));
    });

    test('works for a package in a subdirectory', () async {
      await d.dir('pkg', [
        d.dir('lib', [d.file('a.dart', 'void old() {}\n')]),
      ]).create();
      await gitCommitAll(d.sandbox);
      await d.dir('pkg/lib', [d.file('a.dart', 'void added() {}\n')]).create();

      expect(await run(['--git-diff=HEAD'], root: d.path('pkg')), equals(1));
      expect(
        out.toString(),
        allOf(
          contains('[top-level-function:lib/a.dart:added]'),
          contains('Fixed: top-level-function:lib/a.dart:old'),
        ),
      );
    });

    test('exits 70 for a ref that can not be found', () async {
      expect(
        await run(['--git-diff=origin/main']),
        equals(ExitCode.software.code),
      );
      expect(
        err.toString(),
        equals(
          'Could not find the git ref `origin/main`. In a shallow clone, '
          'fetch it first.\n',
        ),
      );
      expect(out.toString(), isEmpty);
    });

    test('exits 70 outside a git repository', () async {
      // The sandbox is a repository, so use a directory outside it.
      final plain = await Directory.systemTemp.createTemp('theseus_');
      addTearDown(() => plain.delete(recursive: true));
      expect(
        await run(['--git-diff=main'], root: plain.path),
        equals(ExitCode.software.code),
      );
      expect(err.toString(), contains('is not in a git repository.'));
    });
  });
}
