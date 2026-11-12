import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:vaixell/vaixell.dart';
import 'package:vaixell_cli/src/commands/commands.dart';
import 'package:vaixell_cli/src/version.dart';

/// {@template vaixell_command_runner}
/// A [CommandRunner] for the CLI.
///
/// ```bash
/// $ vaixell --version
/// ```
/// {@endtemplate}
class VaixellCommandRunner({
  Logger? logger,
  PubUpdater? pubUpdater,
  bool? interactive,
  List<RuleEntry> rules = Recommended.rules,
}) extends CompletionCommandRunner<int> {
  /// {@macro vaixell_command_runner}
  ///
  /// [interactive] controls the update check and shell completion
  /// auto-install. It defaults to `true` when stdout is a terminal and the
  /// `CI` environment variable is not set.
  ///
  /// `vaixell check` runs [rules], which are vaixell's [Recommended.rules] by
  /// default.
  this
    : super(
        'vaixell',
        'Checks architecture rules in Dart and Flutter repositories without '
            'resolving types or running pub get.',
      ) {
    argParser
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print the current version.',
      )
      ..addFlag(
        'verbose',
        help: 'Noisy logging, including all shell commands executed.',
      );

    addCommand(_check);
    addCommand(UpdateCommand(logger: _logger, pubUpdater: _pubUpdater));
  }

  /// The name of the package on pub.dev, used to check for updates.
  static const String packageName = CliPackage.name;

  /// The current version of the CLI.
  static const String packageVersion = CliPackage.version;

  final Logger _logger = logger ?? Logger();
  final PubUpdater _pubUpdater = pubUpdater ?? PubUpdater();
  final bool _interactive =
      interactive ??
      (stdout.hasTerminal && !Platform.environment.containsKey('CI'));
  late final CheckCommand _check = CheckCommand(logger: _logger, rules: _rules);
  final List<RuleEntry> _rules = rules;

  @override
  void printUsage() => _logger.info(usage);

  bool _isMachineReadable = false;

  /// Disabled when not interactive, and for machine-readable output, since
  /// installing completion files logs to stdout and would corrupt the report.
  @override
  bool get enableAutoInstall => _interactive && !_isMachineReadable;

  @override
  Future<int> run(Iterable<String> args) async {
    final ArgResults topLevelResults;
    try {
      topLevelResults = parse(args);
    } on UsageException catch (e) {
      // `parse` reports invalid arguments as usage errors too.
      return _usageError(e.message, e.usage);
    }
    if (topLevelResults['verbose'] == true) {
      _logger.level = Level.verbose;
    }
    try {
      return await runCommand(topLevelResults) ?? ExitCode.success.code;
    } on UsageException catch (e) {
      return _usageError(e.message, e.usage);
    }
  }

  /// Logs [message] and [usage], and returns the usage exit code.
  int _usageError(String message, String usage) {
    _logger
      ..err(message)
      ..info('')
      ..info(usage);
    return ExitCode.usage.code;
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    final command = topLevelResults.command;
    _isMachineReadable = _isMachineReadableCheck(command);

    // Fast track completion command
    if (command?.name == 'completion') {
      await super.runCommand(topLevelResults);
      return ExitCode.success.code;
    }

    // Logged to stdout, so skipped when stdout is a machine-readable report
    if (!_isMachineReadable) _logArguments(topLevelResults);

    final exitCode = topLevelResults['version'] == true
        ? _printVersion()
        : await super.runCommand(topLevelResults);

    if (_shouldCheckForUpdates(command)) {
      await _checkForUpdates();
    }

    return exitCode;
  }

  bool _isMachineReadableCheck(ArgResults? command) =>
      command?.name == CheckCommand.commandName &&
      _check.isMachineReadable(command!.option('format'));

  /// Whether to check for updates: only when interactive, and not for the
  /// update command or a machine-readable report on stdout.
  bool _shouldCheckForUpdates(ArgResults? command) =>
      _interactive &&
      !_isMachineReadable &&
      command?.name != UpdateCommand.commandName;

  void _logArguments(ArgResults topLevelResults) {
    _logger
      ..detail('Argument information:')
      ..detail('  Top level options:');
    _logParsedOptions(topLevelResults, indent: '  ');

    final command = topLevelResults.command;
    if (command == null) {
      return;
    }
    _logger
      ..detail('  Command: ${command.name}')
      ..detail('    Command options:');
    _logParsedOptions(command, indent: '    ');
  }

  void _logParsedOptions(ArgResults results, {required String indent}) {
    for (final option in results.options.where(results.wasParsed)) {
      _logger.detail('$indent- $option: ${results[option]}');
    }
  }

  int _printVersion() {
    _logger.info(packageVersion);
    return ExitCode.success.code;
  }

  /// Checks if [packageVersion] is the most recent one. If not, show a prompt
  /// to the user.
  Future<void> _checkForUpdates() async {
    try {
      final latestVersion = await _pubUpdater.getLatestVersion(packageName);
      final isUpToDate = packageVersion == latestVersion;
      if (!isUpToDate) {
        _logger
          ..info('')
          ..info('''
${lightYellow.wrap('Update available!')} ${lightCyan.wrap(packageVersion)} \u2192 ${lightCyan.wrap(latestVersion)}
Run ${lightCyan.wrap('$executableName update')} to update''');
      }
    } on Exception catch (_) {
      _logger.err('Failed to check for updates.');
    }
  }
}
