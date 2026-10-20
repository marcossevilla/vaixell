import 'package:args/args.dart';
import 'package:io/io.dart';
import 'package:theseus_cli/src/version.dart';

/// The `theseus` command line interface.
///
/// Parses arguments and returns a process exit code that follows
/// `package:io`'s [ExitCode].
class TheseusCommand {
  /// Creates a command that writes normal output to `stdout` and diagnostics
  /// to `stderr`.
  TheseusCommand({required this._stdout, required this._stderr});

  final StringSink _stdout;
  final StringSink _stderr;

  final ArgParser _parser = ArgParser(usageLineLength: 80)
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag('version', negatable: false, help: 'Print the theseus version.')
    ..addOption(
      'format',
      allowed: ['text', 'json', 'github'],
      defaultsTo: 'text',
      help: 'The output format.',
    )
    ..addOption(
      'git-diff',
      valueHelp: 'ref',
      help:
          'Report only violations added or fixed since the merge-base of '
          '<ref> and HEAD.',
    )
    ..addOption(
      'baseline',
      valueHelp: 'file',
      help: 'Suppress the violation ids listed in <file>.',
    )
    ..addOption(
      'write-baseline',
      valueHelp: 'file',
      help: 'Write the current violation ids to <file>.',
    );

  /// The usage text printed by `--help`.
  String get usage =>
      'Checks architecture rules in Dart and Flutter repositories.\n'
      '\n'
      'Usage: theseus [options] [paths...]\n'
      '\n'
      '${_parser.usage}';

  /// Runs the command with [arguments] and returns the exit code.
  Future<int> run(List<String> arguments) async {
    final ArgResults results;
    try {
      results = _parser.parse(arguments);
    } on FormatException catch (error) {
      _stderr
        ..writeln(error.message)
        ..writeln()
        ..writeln(usage);
      return ExitCode.usage.code;
    }

    if (results.flag('help')) {
      _stdout.writeln(usage);
      return ExitCode.success.code;
    }
    if (results.flag('version')) {
      _stdout.writeln(TheseusVersion.current);
      return ExitCode.success.code;
    }
    return ExitCode.success.code;
  }
}
