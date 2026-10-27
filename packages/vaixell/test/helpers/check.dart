import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vaixell/vaixell.dart';

class _MockLogger extends Mock implements Logger;

/// Returns a logger that writes `write` and `info` output to [out], and
/// `err` and `warn` output to [err].
Logger bufferedLogger({required StringSink out, required StringSink err}) {
  final logger = _MockLogger();
  when(() => logger.write(any())).thenAnswer(
    (invocation) => out.write(invocation.positionalArguments.single),
  );
  when(() => logger.info(any())).thenAnswer(
    (invocation) => out.writeln(invocation.positionalArguments.single),
  );
  when(() => logger.err(any())).thenAnswer(
    (invocation) => err.writeln(invocation.positionalArguments.single),
  );
  when(() => logger.warn(any(), tag: any(named: 'tag'))).thenAnswer(
    (invocation) => err.writeln(invocation.positionalArguments.single),
  );
  return logger;
}

/// Runs `vaixell check` with [arguments] in [root], writing the output to
/// [out] and [err], and returns the exit code.
///
/// [environment] replaces the process environment when given.
///
/// Usage errors throw a [UsageException], which `VaixellCommandRunner`
/// turns into exit code 64.
Future<int?> runCheck(
  List<String> arguments, {
  required String root,
  required StringSink out,
  required StringSink err,
  Map<String, String>? environment,
}) {
  final runner = CommandRunner<int>('vaixell', '')
    ..addCommand(
      CheckCommand(
        logger: bufferedLogger(out: out, err: err),
        root: Directory(root),
        environment: environment,
      ),
    );
  return runner.run([CheckCommand.commandName, ...arguments]);
}
