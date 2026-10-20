@Tags(['e2e'])
library;

import 'package:io/io.dart';
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';
import 'package:theseus_cli/theseus_cli.dart';

Future<TestProcess> _theseus(List<String> arguments) =>
    TestProcess.start('dart', ['run', 'bin/theseus.dart', ...arguments]);

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
}
