@Tags(['e2e'])
library;

import 'package:io/io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';
import 'package:theseus_cli/theseus_cli.dart';

import 'helpers/git_repo.dart';

final String _script = p.absolute('bin', 'theseus.dart');

Future<TestProcess> _theseus(
  List<String> arguments, {
  String? workingDirectory,
}) => TestProcess.start('dart', [
  'run',
  _script,
  ...arguments,
], workingDirectory: workingDirectory);

void main() {
  test('--help prints usage', () async {
    final process = await _theseus(['--help']);
    await expectLater(
      process.stdout,
      emitsThrough('Usage: theseus [options] [paths...]'),
    );
    await process.shouldExit(ExitCode.success.code);
  });

  test('--version prints the pubspec version', () async {
    final process = await _theseus(['--version']);
    expect(await process.stdout.next, equals(TheseusVersion.current));
    await process.shouldExit(ExitCode.success.code);
  });

  test('an unknown flag exits 64 with usage on stderr', () async {
    final process = await _theseus(['--nope']);
    await expectLater(
      process.stderr,
      emitsThrough('Usage: theseus [options] [paths...]'),
    );
    await expectLater(process.stdout, emitsDone);
    await process.shouldExit(ExitCode.usage.code);
  });

  test('reports violations in a package and exits 1', () async {
    await d.dir('pkg', [
      d.file('pubspec.yaml', 'name: pkg\n'),
      d.dir('bin', [d.file('pkg.dart', 'void helper() {}\n')]),
      d.dir('lib', [
        d.file('a.dart', '// A comment.\n\nvoid foo() {}\n'),
        d.file('b.dart', 'class B {\n'),
        d.file('a.g.dart', 'void generated() {}\n'),
        d.file('main.dart', 'void main() {}\n'),
      ]),
    ]).create();

    final process = await _theseus([], workingDirectory: d.path('pkg'));
    expect(
      await process.stdout.next,
      equals(
        'lib/a.dart:3:6: error: Top-level function `foo` is not allowed. '
        'Move it into a class. [top-level-function:lib/a.dart:foo]',
      ),
    );
    expect(
      await process.stdout.next,
      allOf(startsWith('lib/b.dart:'), endsWith('[parse-error:lib/b.dart]')),
    );
    expect(await process.stdout.next, equals('2 violations found.'));
    await process.shouldExit(1);
  });

  test('exits 0 on a clean package', () async {
    await d.dir('pkg', [
      d.dir('lib', [d.file('main.dart', 'void main() {}\n')]),
    ]).create();

    final process = await _theseus([], workingDirectory: d.path('pkg'));
    expect(await process.stdout.next, equals('No violations found.'));
    await process.shouldExit(ExitCode.success.code);
  });

  test('exits 78 on an invalid config', () async {
    await d.dir('pkg', [
      d.file('analysis_options.yaml', 'theseus:\n  rules:\n    nope: off\n'),
      d.dir('lib', [d.file('main.dart', 'void main() {}\n')]),
    ]).create();

    final process = await _theseus([], workingDirectory: d.path('pkg'));
    expect(
      await process.stderr.next,
      startsWith('analysis_options.yaml:3:5: Unknown rule `nope`.'),
    );
    await process.shouldExit(ExitCode.config.code);
  });

  test('--git-diff reports new and fixed ids', () async {
    await d.dir('pkg', [
      d.dir('lib', [d.file('a.dart', 'void old() {}\n')]),
    ]).create();
    final pkg = d.path('pkg');
    await gitInit(pkg);
    await gitCommitAll(pkg);
    await d.dir('pkg/lib', [d.file('a.dart', 'void added() {}\n')]).create();

    final process = await _theseus(['--git-diff=main'], workingDirectory: pkg);
    expect(
      await process.stdout.next,
      endsWith('[top-level-function:lib/a.dart:added]'),
    );
    expect(
      await process.stdout.next,
      equals('Fixed: top-level-function:lib/a.dart:old'),
    );
    expect(await process.stdout.next, equals('1 new violation, 1 fixed.'));
    await process.shouldExit(1);
  });

  test('--git-diff exits 70 outside a git repository', () async {
    await d.dir('pkg', [d.dir('lib')]).create();
    final process = await _theseus([
      '--git-diff=main',
    ], workingDirectory: d.path('pkg'));
    expect(await process.stderr.next, endsWith('is not in a git repository.'));
    await process.shouldExit(ExitCode.software.code);
  });
}
