import 'package:io/io.dart';
import 'package:test/test.dart';
import 'package:theseus_cli/theseus_cli.dart';

void main() {
  group(TheseusCommand, () {
    late StringBuffer out;
    late StringBuffer err;
    late TheseusCommand command;

    setUp(() {
      out = StringBuffer();
      err = StringBuffer();
      command = TheseusCommand(stdout: out, stderr: err);
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

    test('no arguments exits 0', () async {
      expect(await command.run([]), equals(ExitCode.success.code));
    });
  });
}
