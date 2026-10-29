import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

import '../../helpers/check.dart';

void main() {
  group(CheckCommand, () {
    late StringBuffer out;
    late StringBuffer err;

    setUp(() {
      out = StringBuffer();
      err = StringBuffer();
    });

    Future<int?> run(List<String> arguments) =>
        runCheck(arguments, root: d.sandbox, out: out, err: err);

    Matcher usageError(Matcher message) => throwsA(
      isA<UsageException>().having((e) => e.message, 'message', message),
    );

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

    test('reports violations and exits 1', () async {
      await d.dir('lib', [d.file('a.dart', 'void foo() {}\n')]).create();
      expect(await run([]), equals(1));
      expect(
        out.toString(),
        equals(
          'lib/a.dart:1:6: error: Top-level function `foo` is not allowed. '
          'Move it into a class. [top-level-function:lib/a.dart:foo]\n'
          '1 violation found.\n',
        ),
      );
      expect(err.toString(), isEmpty);
    });

    test('--format=json writes the JSON document', () async {
      await d.dir('lib', [d.file('a.dart', 'void foo() {}\n')]).create();
      expect(await run(['--format=json']), equals(1));
      expect(out.toString(), startsWith('{\n'));
      expect(out.toString(), endsWith('}\n'));
    });

    test('exits 0 for a clean package', () async {
      await d.dir('lib', [d.file('main.dart', 'void main() {}\n')]).create();
      expect(await run([]), equals(ExitCode.success.code));
      expect(out.toString(), equals('No violations found.\n'));
    });

    test('exits 0 when the config makes violations warnings', () async {
      await d.dir('lib', [d.file('a.dart', 'void foo() {}\n')]).create();
      await d
          .file(
            'analysis_options.yaml',
            'vaixell:\n  rules:\n    top-level-function: warning\n',
          )
          .create();
      expect(await run([]), equals(ExitCode.success.code));
      expect(out.toString(), contains('lib/a.dart:1:6: warning: '));
    });

    test('exits 78 on an invalid config', () async {
      await d.dir('lib', [d.file('a.dart', 'void foo() {}\n')]).create();
      await d.file('analysis_options.yaml', 'vaixell:\n  rulez: {}\n').create();
      expect(await run([]), equals(ExitCode.config.code));
      expect(
        err.toString(),
        startsWith('analysis_options.yaml:2:3: Unknown key `rulez`'),
      );
      expect(out.toString(), isEmpty);
    });

    test('defaults to the current directory', () async {
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

    test('requires at least one reporter', () {
      expect(
        () => CheckCommand(
          logger: bufferedLogger(out: out, err: err),
          reporters: {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    group('collaborators', () {
      const report = Report.full([
        Violation(
          id: 'top-level-function:lib/a.dart:foo',
          rule: 'top-level-function',
          severity: Severity.error,
          path: 'lib/a.dart',
          line: 1,
          column: 6,
          message: 'message',
        ),
      ]);

      late _MockCheck check;
      late _MockWriteBaseline writeBaseline;
      late _MockReporter reporter;

      setUpAll(() {
        registerFallbackValue(report);
        registerFallbackValue(StringBuffer());
      });

      setUp(() {
        check = _MockCheck();
        writeBaseline = _MockWriteBaseline();
        reporter = _MockReporter();
        when(
          () => check(
            paths: any(named: 'paths'),
            gitDiff: any(named: 'gitDiff'),
            baseline: any(named: 'baseline'),
          ),
        ).thenAnswer((_) async => report);
        when(() => reporter.write(any(), any())).thenAnswer(
          (invocation) => (invocation.positionalArguments[1] as StringSink)
              .writeln('custom'),
        );
      });

      Future<int?> runWith(
        List<String> arguments, {
        Map<String, Reporter>? reporters,
      }) {
        final runner = CommandRunner<int>('vaixell', '')
          ..addCommand(
            CheckCommand(
              logger: bufferedLogger(out: out, err: err),
              root: Directory(d.sandbox),
              check: check,
              writeBaseline: writeBaseline,
              reporters: reporters ?? {'custom': reporter},
            ),
          );
        return runner.run([CheckCommand.commandName, ...arguments]);
      }

      test('checks with the given check and reporter', () async {
        await d.dir('pkg').create();
        expect(
          await runWith(['--git-diff=main', '--baseline=b.json', 'pkg']),
          equals(1),
        );
        verify(() => check(paths: ['pkg'], gitDiff: 'main', baseline: 'b.json'))
            .called(1);
        verify(() => reporter.write(report, any())).called(1);
        expect(out.toString(), equals('custom\n'));
      });

      test('writes baselines with the given writer', () async {
        when(() => writeBaseline(any(), paths: any(named: 'paths')))
            .thenAnswer((_) async => Baseline(['a', 'b']));
        expect(
          await runWith(['--write-baseline=b.json']),
          equals(ExitCode.success.code),
        );
        verify(() => writeBaseline('b.json', paths: [])).called(1);
        verifyNever(
          () => check(
            paths: any(named: 'paths'),
            gitDiff: any(named: 'gitDiff'),
            baseline: any(named: 'baseline'),
          ),
        );
        expect(out.toString(), isEmpty);
        expect(err.toString(), equals('Wrote 2 violation ids to b.json.\n'));
      });

      test('writes the baseline status to stdout for a TextReporter', () async {
        when(() => writeBaseline(any(), paths: any(named: 'paths')))
            .thenAnswer((_) async => Baseline(['a']));
        expect(
          await runWith(
            ['--write-baseline=b.json'],
            reporters: {'plain': const TextReporter()},
          ),
          equals(ExitCode.success.code),
        );
        expect(out.toString(), equals('Wrote 1 violation id to b.json.\n'));
        expect(err.toString(), isEmpty);
      });

      test('only allows the given formats', () async {
        await expectLater(
          runWith(['--format=text']),
          usageError(contains('"text" is not an allowed value')),
        );
      });
    });
  });
}

class _MockCheck extends Mock implements Check;

class _MockWriteBaseline extends Mock implements WriteBaseline;

class _MockReporter extends Mock implements Reporter;
