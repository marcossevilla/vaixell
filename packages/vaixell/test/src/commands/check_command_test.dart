import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

import '../../helpers/check.dart';

const _error = Violation(
  id: 'top-level-function:lib/a.dart:foo',
  rule: 'top-level-function',
  severity: Severity.error,
  path: 'lib/a.dart',
  line: 1,
  column: 6,
  message: 'message',
);

const _warning = Violation(
  id: 'top-level-variable:lib/a.dart:limit',
  rule: 'top-level-variable',
  severity: Severity.warning,
  path: 'lib/a.dart',
  line: 2,
  column: 7,
  message: 'message',
);

void main() {
  group(CheckCommand, () {
    late StringBuffer out;
    late StringBuffer err;
    late _MockCheck check;
    late _MockWriteBaseline writeBaseline;

    setUpAll(() {
      registerFallbackValue(const Report.full([]));
      registerFallbackValue(StringBuffer());
    });

    setUp(() {
      out = StringBuffer();
      err = StringBuffer();
      check = _MockCheck();
      writeBaseline = _MockWriteBaseline();
    });

    void stubCheck(Future<Report> Function() answer) => when(
      () => check(
        paths: any(named: 'paths'),
        gitDiff: any(named: 'gitDiff'),
        baseline: any(named: 'baseline'),
      ),
    ).thenAnswer((_) => answer());

    void stubWriteBaseline(Baseline baseline) =>
        when(() => writeBaseline(any(), paths: any(named: 'paths')))
            .thenAnswer((_) async => baseline);

    void verifyNoCheck() => verifyNever(
      () => check(
        paths: any(named: 'paths'),
        gitDiff: any(named: 'gitDiff'),
        baseline: any(named: 'baseline'),
      ),
    );

    Future<int?> run(
      List<String> arguments, {
      Map<String, Reporter>? reporters,
      Map<String, String> environment = const {},
    }) {
      final runner = CommandRunner<int>('vaixell', '')
        ..addCommand(
          CheckCommand(
            logger: bufferedLogger(out: out, err: err),
            root: Directory(d.sandbox),
            environment: environment,
            check: check,
            writeBaseline: writeBaseline,
            reporters: reporters,
          ),
        );
      return runner.run([CheckCommand.commandName, ...arguments]);
    }

    Matcher usageError(Matcher message) => throwsA(
      isA<UsageException>().having((e) => e.message, 'message', message),
    );

    group('parsing', () {
      test('--help prints usage to stdout', () async {
        expect(await run(['--help']), isNull);
        expect(
          out.toString(),
          allOf([
            contains('Usage: vaixell check [options] [paths...]'),
            contains('the workspace members, packages/* and pkgs/*.'),
            contains('--help'),
            contains('--format'),
            contains('--git-diff=<ref>'),
            contains('--baseline=<file>'),
            contains('--write-baseline=<file>'),
          ]),
        );
        expect(err.toString(), isEmpty);
      });

      test('an unknown flag is a usage error', () async {
        await expectLater(
          run(['--nope']),
          usageError(equals('Could not find an option named "--nope".')),
        );
      });

      test('an invalid --format value is a usage error', () async {
        await expectLater(
          run(['--format=xml']),
          usageError(contains('"xml" is not an allowed value')),
        );
      });

      for (final other in ['--git-diff=main', '--baseline=b.json']) {
        test('--write-baseline with $other is a usage error', () async {
          await expectLater(
            run(['--write-baseline=b.json', other]),
            usageError(startsWith('--write-baseline can not be combined')),
          );
          verifyNever(() => writeBaseline(any(), paths: any(named: 'paths')));
        });
      }

      test('passes the paths and options to check', () async {
        stubCheck(() async => const Report.full([]));
        await d.dir('pkg').create();
        await run(['--git-diff=main', '--baseline=b.json', 'pkg']);
        verify(() => check(paths: ['pkg'], gitDiff: 'main', baseline: 'b.json'))
            .called(1);
      });

      test('checks the discovered packages without paths', () async {
        stubCheck(() async => const Report.full([]));
        await run([]);
        verify(() => check(paths: [])).called(1);
      });

      test('passes the paths and file to writeBaseline', () async {
        stubWriteBaseline(Baseline(const []));
        await d.dir('pkg').create();
        await run(['--write-baseline=b.json', 'pkg']);
        verify(() => writeBaseline('b.json', paths: ['pkg'])).called(1);
        verifyNoCheck();
      });
    });

    group('path validation', () {
      test('a path outside the root is a usage error', () async {
        await expectLater(
          run(['..']),
          usageError(startsWith('Path `..` is outside `')),
        );
        expect(out.toString(), isEmpty);
        verifyNoCheck();
      });

      test('a path that is not a directory is a usage error', () async {
        await d.file('pubspec.yaml', 'name: a\n').create();
        await expectLater(
          run(['missing']),
          usageError(equals('Path `missing` is not a directory.')),
        );
        await expectLater(
          run(['pubspec.yaml']),
          usageError(equals('Path `pubspec.yaml` is not a directory.')),
        );
        verifyNoCheck();
      });

      test('a positional . is the root', () async {
        stubCheck(() async => const Report.full([]));
        expect(await run(['.']), equals(ExitCode.success.code));
        verify(() => check(paths: ['.'])).called(1);
      });
    });

    group('exit codes', () {
      test('exits 1 when a violation is an error', () async {
        stubCheck(() async => const Report.full([_error, _warning]));
        expect(await run([]), equals(1));
      });

      test('exits 0 without violations', () async {
        stubCheck(() async => const Report.full([]));
        expect(await run([]), equals(ExitCode.success.code));
      });

      test('exits 0 when every violation is a warning', () async {
        stubCheck(() async => const Report.full([_warning]));
        expect(await run([]), equals(ExitCode.success.code));
      });

      test('exits 0 when violations are only fixed', () async {
        stubCheck(
          () async => const Report.compared(ReportMode.diff, [
            _error,
          ], DiffResult(added: [], fixed: ['top-level-function:lib/a.dart:x'])),
        );
        expect(await run(['--git-diff=main']), equals(ExitCode.success.code));
      });

      test('exits 1 when a new violation is an error', () async {
        stubCheck(
          () async => const Report.compared(ReportMode.baseline, [
            _error,
            _warning,
          ], DiffResult(added: [_error], fixed: [])),
        );
        expect(await run(['--baseline=b.json']), equals(1));
      });

      test('exits 0 when every new violation is a warning', () async {
        stubCheck(
          () async => const Report.compared(ReportMode.diff, [
            _error,
            _warning,
          ], DiffResult(added: [_warning], fixed: [])),
        );
        expect(await run(['--git-diff=main']), equals(ExitCode.success.code));
      });

      final errors = <String, (Exception, int)>{
        'ConfigException': (
          const ConfigException(
            'Unknown key `rulez`.',
            path: 'analysis_options.yaml',
            line: 2,
            column: 3,
          ),
          ExitCode.config.code,
        ),
        'BaselineException': (
          const BaselineException('Baseline file `b.json` not found.'),
          ExitCode.config.code,
        ),
        'GitException': (
          const GitException('Not a git repository.'),
          ExitCode.software.code,
        ),
      };
      for (final MapEntry(key: name, value: (error, code)) in errors.entries) {
        test('exits $code on a $name, on stderr only', () async {
          stubCheck(() async => throw error);
          expect(await run([]), equals(code));
          expect(err.toString(), equals('$error\n'));
          expect(out.toString(), isEmpty);
        });

        test('exits $code on a $name with --format=json', () async {
          stubCheck(() async => throw error);
          expect(await run(['--format=json']), equals(code));
          expect(err.toString(), equals('$error\n'));
          expect(out.toString(), isEmpty);
        });
      }

      test('exits 78 when writing a baseline fails on a config', () async {
        const error = ConfigException(
          'Unknown key `bad`.',
          path: 'analysis_options.yaml',
          line: 2,
          column: 3,
        );
        when(() => writeBaseline(any(), paths: any(named: 'paths')))
            .thenAnswer((_) async => throw error);
        expect(
          await run(['--write-baseline=b.json']),
          equals(ExitCode.config.code),
        );
        expect(err.toString(), equals('$error\n'));
        expect(out.toString(), isEmpty);
      });
    });

    group('output', () {
      test('writes the text report to stdout by default', () async {
        stubCheck(() async => const Report.full([_error]));
        await run([]);
        expect(
          out.toString(),
          equals(
            'lib/a.dart:1:6: error: message '
            '[top-level-function:lib/a.dart:foo]\n'
            '1 violation found.\n',
          ),
        );
        expect(err.toString(), isEmpty);
      });

      test('--format=json writes the JSON document to stdout', () async {
        stubCheck(() async => const Report.full([_error]));
        await run(['--format=json']);
        final output = StringBuffer();
        const JsonReporter().write(const Report.full([_error]), output);
        expect(out.toString(), equals(output.toString()));
        expect(err.toString(), isEmpty);
      });

      test(
        '--format=github annotates and appends to GITHUB_STEP_SUMMARY',
        () async {
          stubCheck(() async => const Report.full([_error]));
          expect(
            await run(
              ['--format=github'],
              environment: {'GITHUB_STEP_SUMMARY': d.path('summary.md')},
            ),
            equals(1),
          );
          expect(
            out.toString(),
            startsWith('::error file=lib/a.dart,line=1,col=6,'),
          );
          expect(
            File(d.path('summary.md')).readAsStringSync(),
            startsWith('## vaixell\n'),
          );
        },
      );

      test('--format=github skips an empty GITHUB_STEP_SUMMARY', () async {
        stubCheck(() async => const Report.full([_error]));
        expect(
          await run(
            ['--format=github'],
            environment: {'GITHUB_STEP_SUMMARY': ''},
          ),
          equals(1),
        );
        expect(Directory(d.sandbox).listSync(), isEmpty);
      });

      test('--format=github skips a missing GITHUB_STEP_SUMMARY', () async {
        stubCheck(() async => const Report.full([_error]));
        expect(await run(['--format=github']), equals(1));
        expect(Directory(d.sandbox).listSync(), isEmpty);
      });

      test('writes the baseline status to stdout in text format', () async {
        stubWriteBaseline(Baseline(const ['a', 'b']));
        expect(
          await run(['--write-baseline=b.json']),
          equals(ExitCode.success.code),
        );
        expect(out.toString(), equals('Wrote 2 violation ids to b.json.\n'));
        expect(err.toString(), isEmpty);
      });

      test('uses the singular for one baseline id', () async {
        stubWriteBaseline(Baseline(const ['a']));
        await run(['--write-baseline=b.json']);
        expect(out.toString(), equals('Wrote 1 violation id to b.json.\n'));
      });

      for (final format in ['json', 'github']) {
        test('keeps stdout empty for --write-baseline in $format', () async {
          stubWriteBaseline(Baseline(const ['a', 'b', 'c']));
          expect(
            await run(['--format=$format', '--write-baseline=b.json']),
            equals(ExitCode.success.code),
          );
          expect(out.toString(), isEmpty);
          expect(err.toString(), equals('Wrote 3 violation ids to b.json.\n'));
        });
      }
    });

    group('reporters', () {
      late _MockReporter reporter;

      setUp(() {
        reporter = _MockReporter();
        when(() => reporter.write(any(), any())).thenAnswer(
          (invocation) => (invocation.positionalArguments[1] as StringSink)
              .writeln('custom'),
        );
      });

      test('writes the report with the given reporter', () async {
        stubCheck(() async => const Report.full([_error]));
        expect(await run([], reporters: {'custom': reporter}), equals(1));
        verify(() => reporter.write(const Report.full([_error]), any()))
            .called(1);
        expect(out.toString(), equals('custom\n'));
      });

      test('writes the baseline status to stdout for a TextReporter', () async {
        stubWriteBaseline(Baseline(const ['a']));
        await run(
          ['--write-baseline=b.json'],
          reporters: {'plain': const TextReporter()},
        );
        expect(out.toString(), equals('Wrote 1 violation id to b.json.\n'));
        expect(err.toString(), isEmpty);
      });

      test('only allows the given formats', () async {
        await expectLater(
          run(['--format=text'], reporters: {'custom': reporter}),
          usageError(contains('"text" is not an allowed value')),
        );
      });

      test('requires at least one reporter', () {
        expect(
          () => CheckCommand(
            logger: bufferedLogger(out: out, err: err),
            reporters: {},
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    test('defaults to checking the current directory', () async {
      await d.dir('lib', [d.file('a.dart', 'void foo() {}\n')]).create();
      final code = await IOOverrides.runZoned(() {
        final runner = CommandRunner<int>('vaixell', '')
          ..addCommand(
            CheckCommand(
              logger: bufferedLogger(out: out, err: err),
            ),
          );
        return runner.run([CheckCommand.commandName]);
      }, getCurrentDirectory: () => Directory(d.sandbox));
      expect(code, equals(1));
      expect(out.toString(), startsWith('lib/a.dart:1:6: error: '));
    });
  });
}

class _MockCheck extends Mock implements Check;

class _MockWriteBaseline extends Mock implements WriteBaseline;

class _MockReporter extends Mock implements Reporter;
