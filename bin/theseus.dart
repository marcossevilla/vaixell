import 'dart:io';

import 'package:theseus_cli/theseus_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await TheseusCommand(
    stdout: stdout,
    stderr: stderr,
  ).run(arguments);
  await Future.wait([stdout.close(), stderr.close()]);
}
