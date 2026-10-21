import 'dart:io';

import 'package:io/io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:theseus_cli/theseus_cli.dart';

import '../helpers/git_repo.dart';

void main() {
  group('package discovery', () {
    late StringBuffer out;
    late StringBuffer err;

    Future<int> run(List<String> arguments) {
      out = StringBuffer();
      err = StringBuffer();
      return TheseusCommand(
        stdout: out,
        stderr: err,
        root: Directory(d.sandbox),
      ).run(arguments);
    }

    List<String> ids() => [
      for (final match in RegExp(
        r'\[([^\]]+)\]$',
        multiLine: true,
      ).allMatches(out.toString()))
        match.group(1)!,
    ];

    setUp(() async {
      await d.file('pubspec.yaml', '''
name: w
workspace:
  - packages/a
  - packages/b
''').create();
      await d
          .file(
            'analysis_options.yaml',
            'theseus:\n  rules:\n    top-level-variable: off\n',
          )
          .create();
      await d.dir('lib', [d.file('root.dart', 'void root() {}\n')]).create();
      await d.dir('packages/a', [
        d.file('pubspec.yaml', 'name: a\n'),
        d.file(
          'analysis_options.yaml',
          'theseus:\n  rules:\n    top-level-function: off\n',
        ),
        d.dir('lib', [d.file('a.dart', 'void a() {}\nfinal x = 1;\n')]),
      ]).create();
      await d.dir('packages/b', [
        d.file('pubspec.yaml', 'name: b\n'),
        d.file('analysis_options.yaml', 'include: package:lints/core.yaml\n'),
        d.dir('lib', [d.file('b.dart', 'void b() {}\nfinal y = 1;\n')]),
      ]).create();
    });

    test('checks every workspace member with its nearest config', () async {
      expect(await run([]), equals(1));
      expect(
        ids(),
        equals([
          'top-level-function:lib/root.dart:root',
          // Package a's own config turns top-level-function off, and
          // doesn't inherit the root's top-level-variable: off.
          'top-level-variable:packages/a/lib/a.dart:x',
          // Package b has no theseus key, so the root config applies.
          'top-level-function:packages/b/lib/b.dart:b',
        ]),
      );
    });

    test('positional paths override discovery', () async {
      expect(await run(['packages/b', 'packages/b/', './packages/b']), 1);
      expect(ids(), equals(['top-level-function:packages/b/lib/b.dart:b']));
    });

    test('a positional . checks only the root package', () async {
      expect(await run(['.']), equals(1));
      expect(ids(), equals(['top-level-function:lib/root.dart:root']));
    });

    test('a path outside the root exits 64', () async {
      expect(await run(['..']), equals(ExitCode.usage.code));
      expect(err.toString(), startsWith('Path `..` is outside `'));
      expect(out.toString(), isEmpty);
    });

    test('a path that is not a directory exits 64', () async {
      expect(await run(['missing']), equals(ExitCode.usage.code));
      expect(err.toString(), startsWith('Path `missing` is not a directory.'));
      expect(await run(['pubspec.yaml']), equals(ExitCode.usage.code));
    });

    test('an invalid workspace exits 78', () async {
      await d.file('pubspec.yaml', 'workspace:\n  - packages/c\n').create();
      expect(await run([]), equals(ExitCode.config.code));
      expect(
        err.toString(),
        equals(
          'pubspec.yaml:2:5: Workspace member `packages/c` has no '
          'pubspec.yaml.\n',
        ),
      );
    });

    test('an invalid member config exits 78 with its path', () async {
      await d
          .file('packages/b/analysis_options.yaml', 'theseus:\n  bad: 1\n')
          .create();
      expect(await run([]), equals(ExitCode.config.code));
      expect(
        err.toString(),
        startsWith('packages/b/analysis_options.yaml:2:3: Unknown key `bad`'),
      );
    });

    test('--git-diff works across workspace members', () async {
      await gitInit(d.sandbox);
      await gitCommitAll(d.sandbox);
      await d.dir('packages/b/lib', [
        d.file('b.dart', 'final y = 1;\nvoid added() {}\n'),
      ]).create();
      await d.dir('packages/c', [
        d.file('pubspec.yaml', 'name: c\n'),
        d.dir('lib', [d.file('c.dart', 'void c() {}\n')]),
      ]).create();
      await d.file('pubspec.yaml', '''
name: w
workspace:
  - packages/a
  - packages/b
  - packages/c
''').create();

      expect(await run(['--git-diff=main']), equals(1));
      expect(
        ids(),
        equals([
          'top-level-function:packages/b/lib/b.dart:added',
          'top-level-function:packages/c/lib/c.dart:c',
        ]),
      );
      expect(
        out.toString(),
        allOf(
          contains('Fixed: top-level-function:packages/b/lib/b.dart:b\n'),
          endsWith('2 new violations, 1 fixed.\n'),
        ),
      );
    });
  });
}
