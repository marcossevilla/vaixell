import 'package:args/command_runner.dart';
import 'package:io/io.dart';
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
      final runner = CommandRunner<int>('vaixell', '')
        ..addCommand(
          CheckCommand(
            logger: bufferedLogger(out: out, err: err),
          ),
        );
      expect(
        await runner.run([CheckCommand.commandName]),
        equals(ExitCode.success.code),
      );
    });
  });
}
