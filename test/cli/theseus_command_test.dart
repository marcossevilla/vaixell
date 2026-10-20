import 'dart:io';

import 'package:io/io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:theseus_cli/theseus_cli.dart';

void main() {
  group(TheseusCommand, () {
    late StringBuffer out;
    late StringBuffer err;
    late TheseusCommand command;

    setUp(() {
      out = StringBuffer();
      err = StringBuffer();
      command = TheseusCommand(
        stdout: out,
        stderr: err,
        root: Directory(d.sandbox),
      );
    });

    test('--help prints usage to stdout and exits 0', () async {
      expect(await command.run(['--help']), equals(ExitCode.success.code));
      expect(out.toString(), equals('${command.usage}\n'));
      expect(err.toString(), isEmpty);
    });

    test('usage lists every option', () {
      expect(
        command.usage,
        allOf([
          contains('Usage: theseus [options] [paths...]'),
          contains('--help'),
          contains('--version'),
          contains('--format'),
          contains('--git-diff=<ref>'),
          contains('--baseline=<file>'),
          contains('--write-baseline=<file>'),
        ]),
      );
    });

    test('--version prints the version and exits 0', () async {
      expect(await command.run(['--version']), equals(ExitCode.success.code));
      expect(out.toString(), equals('${TheseusVersion.current}\n'));
    });

    test('an unknown flag prints usage to stderr and exits 64', () async {
      expect(await command.run(['--nope']), equals(ExitCode.usage.code));
      expect(out.toString(), isEmpty);
      expect(
        err.toString(),
        allOf([
          contains('Could not find an option named "--nope".'),
          contains(command.usage),
        ]),
      );
    });

    test('an invalid --format value exits 64', () async {
      expect(await command.run(['--format=xml']), equals(ExitCode.usage.code));
    });

    test('reports violations and exits 1', () async {
      await d.dir('lib', [d.file('a.dart', 'void foo() {}\n')]).create();
      expect(await command.run([]), equals(1));
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

    test('exits 0 for a clean package', () async {
      await d.dir('lib', [d.file('main.dart', 'void main() {}\n')]).create();
      expect(await command.run([]), equals(ExitCode.success.code));
      expect(out.toString(), equals('No violations found.\n'));
    });

    test('defaults to the current directory', () async {
      final command = TheseusCommand(stdout: out, stderr: err);
      expect(await command.run([]), equals(ExitCode.success.code));
    });

    for (final arguments in [
      ['lib'],
      ['--format=json'],
      ['--git-diff=main'],
      ['--baseline=b.json'],
      ['--write-baseline=b.json'],
    ]) {
      test('rejects unsupported $arguments with exit 64', () async {
        expect(await command.run(arguments), equals(ExitCode.usage.code));
        expect(err.toString(), contains('is not supported yet.'));
        expect(out.toString(), isEmpty);
      });
    }
  });
}
