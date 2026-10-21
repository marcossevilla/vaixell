import 'dart:io';

import 'package:vaixell/vaixell.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await VaixellCommand(
    stdout: stdout,
    stderr: stderr,
  ).run(arguments);
  await Future.wait([stdout.close(), stderr.close()]);
}
