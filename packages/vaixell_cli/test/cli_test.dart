@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';
import 'package:vaixell_cli/vaixell_cli.dart';

import 'helpers/git_repo.dart';

/// The CLI compiled once to a kernel snapshot, so each test starts it in
/// well under a second instead of paying for `dart run`.
late final String _snapshot;

Future<TestProcess> _vaixell(
  List<String> arguments, {
  String? workingDirectory,
}) => TestProcess.start('dart', [
  _snapshot,
  ...arguments,
], workingDirectory: workingDirectory);

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('vaixell_e2e_');
    _snapshot = p.join(dir.path, 'vaixell.dill');
    // `dart` from the PATH: under `flutter test`, Platform.resolvedExecutable
    // is the Flutter test runner.
    final result = await Process.run('dart', [
      'compile',
      'kernel',
      p.absolute('bin', 'vaixell.dart'),
      '-o',
      _snapshot,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Could not compile the CLI: ${result.stderr}');
    }
    addTearDown(() => dir.delete(recursive: true));
  });

  group('vaixell', () {
    test('an unknown flag exits 64 with the error on stderr', () async {
      final process = await _vaixell(['check', '--nope']);
      expect(
        await process.stderr.next,
        equals('Could not find an option named "--nope".'),
      );
      await expectLater(
        process.stdout,
        emitsThrough('Usage: vaixell check [options] [paths...]'),
      );
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

      final process = await _vaixell([
        'check',
      ], workingDirectory: d.path('pkg'));
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
      await process.shouldExit(CheckCommand.violationsExitCode);
    });

    test('exits 0 on a clean package', () async {
      await d.dir('pkg', [
        d.dir('lib', [d.file('main.dart', 'void main() {}\n')]),
      ]).create();

      final process = await _vaixell([
        'check',
      ], workingDirectory: d.path('pkg'));
      expect(await process.stdout.next, equals('No violations found.'));
      await process.shouldExit(ExitCode.success.code);
    });

    test('exits 78 on an invalid config', () async {
      await d.dir('pkg', [
        d.file('analysis_options.yaml', 'vaixell:\n  rules:\n    nope: off\n'),
        d.dir('lib', [d.file('main.dart', 'void main() {}\n')]),
      ]).create();

      final process = await _vaixell([
        'check',
      ], workingDirectory: d.path('pkg'));
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

      final process = await _vaixell([
        'check',
        '--git-diff=main',
      ], workingDirectory: pkg);
      expect(
        await process.stdout.next,
        endsWith('[top-level-function:lib/a.dart:added]'),
      );
      expect(
        await process.stdout.next,
        equals('Fixed: top-level-function:lib/a.dart:old'),
      );
      expect(await process.stdout.next, equals('1 new violation, 1 fixed.'));
      await process.shouldExit(CheckCommand.violationsExitCode);
    });

    test('--git-diff exits 65 outside a git repository', () async {
      await d.dir('pkg', [d.dir('lib')]).create();
      final process = await _vaixell([
        'check',
        '--git-diff=main',
      ], workingDirectory: d.path('pkg'));
      expect(
        await process.stderr.next,
        endsWith('is not in a git repository.'),
      );
      await process.shouldExit(ExitCode.data.code);
    });

    test('checks workspace members from the root', () async {
      await d.dir('repo', [
        d.file('pubspec.yaml', 'name: w\nworkspace:\n  - packages/a\n'),
        d.dir('packages/a', [
          d.file('pubspec.yaml', 'name: a\n'),
          d.dir('lib', [d.file('a.dart', 'void a() {}\n')]),
        ]),
      ]).create();

      final process = await _vaixell([
        'check',
      ], workingDirectory: d.path('repo'));
      expect(
        await process.stdout.next,
        endsWith('[top-level-function:packages/a/lib/a.dart:a]'),
      );
      expect(await process.stdout.next, equals('1 violation found.'));
      await process.shouldExit(CheckCommand.violationsExitCode);
    });

    test('writes a baseline, then checks against it', () async {
      await d.dir('pkg', [
        d.dir('lib', [d.file('a.dart', 'void foo() {}\n')]),
      ]).create();
      final pkg = d.path('pkg');

      var process = await _vaixell([
        'check',
        '--write-baseline=b.json',
      ], workingDirectory: pkg);
      expect(
        await process.stdout.next,
        equals('Wrote 1 violation id to b.json.'),
      );
      await process.shouldExit(ExitCode.success.code);
      await d.dir('pkg', [
        d.file('b.json', contains('top-level-function:lib/a.dart:foo')),
      ]).validate();

      process = await _vaixell([
        'check',
        '--baseline=b.json',
      ], workingDirectory: pkg);
      expect(await process.stdout.next, equals('0 new violations, 0 fixed.'));
      await process.shouldExit(ExitCode.success.code);

      process = await _vaixell([
        'check',
        '--baseline=missing.json',
      ], workingDirectory: pkg);
      expect(await process.stderr.next, endsWith('missing.json` not found.'));
      await process.shouldExit(ExitCode.config.code);
    });

    test('exits 78 when the baseline directory is missing', () async {
      await d.dir('pkg', [d.dir('lib')]).create();
      final process = await _vaixell([
        'check',
        '--write-baseline=missing/b.json',
      ], workingDirectory: d.path('pkg'));
      expect(
        await process.stderr.next,
        startsWith('Could not write baseline file '),
      );
      await process.shouldExit(ExitCode.config.code);
    });

    test('--format=json prints only a JSON document on stdout', () async {
      await d.dir('pkg', [
        d.dir('lib', [d.file('a.dart', 'void foo() {}\n')]),
      ]).create();

      final process = await _vaixell([
        'check',
        '--format=json',
      ], workingDirectory: d.path('pkg'));
      final stdout = (await process.stdout.rest.toList()).join('\n');
      final json = jsonDecode(stdout) as Map<String, Object?>;
      expect(json['mode'], equals('full'));
      expect(json['summary'], containsPair('violations', 1));
      await process.shouldExit(CheckCommand.violationsExitCode);
    });
  });
}
