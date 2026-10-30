import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';

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
