import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/baseline/baseline.dart';
import 'package:vaixell/src/check/check.dart';
import 'package:vaixell/src/check/write_baseline.dart';
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/git/git_runner.dart';
import 'package:vaixell/src/report/github_reporter.dart';
import 'package:vaixell/src/report/json_reporter.dart';
import 'package:vaixell/src/report/reporter.dart';
import 'package:vaixell/src/report/text_reporter.dart';
import 'package:vaixell/src/violation/violation.dart';

/// {@template check_command}
/// `vaixell check`: checks architecture rules in the given packages.
///
/// Returns a process exit code that follows `package:io`'s [ExitCode].
/// {@endtemplate}
class CheckCommand({
  required final Logger _logger,
  Directory? root,
  Map<String, String>? environment,
  Check? check,
  WriteBaseline? writeBaseline,
  Map<String, Reporter>? reporters,
}) extends Command<int> {
  /// {@macro check_command}
  ///
  /// Checks the packages in [root] (the current directory by default) with
  /// [check], and writes baselines with [writeBaseline], both on [root] by
  /// default. The report goes to stdout and diagnostics go to stderr, both
  /// through the logger.
  ///
  /// [reporters] maps each `--format` value to its [Reporter], and the first
  /// one is the default. By default they're a [TextReporter], a [JsonReporter]
  /// and a [GithubReporter] whose summary goes to `GITHUB_STEP_SUMMARY` from
  /// [environment] (the process environment by default).
  this {
    argParser
      ..addOption(
        'format',
        allowed: _reporters.keys,
        defaultsTo: _reporters.keys.first,
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
  }

  /// The name of this command.
  static const String commandName = 'check';

  /// The exit code when any reported violation is an error.
  static const int _violationsExitCode = 1;

  final Directory _root = root ?? Directory.current;
  final Check _check = check ?? Check(root: (root ?? Directory.current).path);
  final WriteBaseline _writeBaseline =
      writeBaseline ?? WriteBaseline(root: (root ?? Directory.current).path);
  final Map<String, Reporter> _reporters =
      reporters ??
      {
        'text': const TextReporter(),
        'json': const JsonReporter(),
        'github': GithubReporter(
          summaryPath: switch ((environment ??
              Platform.environment)['GITHUB_STEP_SUMMARY']) {
            '' => null,
            final path => path,
          },
        ),
      };

  @override
  String get name => commandName;

  @override
  String get description =>
      'Check architecture rules in Dart and Flutter packages.\n'
      '\n'
      'Checks the given package directories, or the packages found in the\n'
      'current directory: the workspace members, packages/* and pkgs/*.';

  @override
  String get invocation => 'vaixell check [options] [paths...]';

  @override
  void printUsage() => _logger.info(usage);

  @override
  Future<int> run() async {
    final results = argResults!;
    final ref = results.option('git-diff');
    final baselinePath = results.option('baseline');
    final writeBaselinePath = results.option('write-baseline');
    if (writeBaselinePath != null && (ref != null || baselinePath != null)) {
      usageException(
        '--write-baseline can not be combined with --git-diff or --baseline.',
      );
    }

    final invalidPath = results.rest.map(_invalidPath).nonNulls.firstOrNull;
    if (invalidPath != null) usageException(invalidPath);

    try {
      if (writeBaselinePath != null) {
        final baseline = await _writeBaseline(
          writeBaselinePath,
          paths: results.rest,
        );
        final count = baseline.ids.length;
        final status =
            'Wrote $count violation id${count == 1 ? '' : 's'} to '
            '$writeBaselinePath.';
        // Keep stdout empty in machine-readable formats.
        if (results.option('format') != 'text') {
          _logger.warn(status, tag: '');
        } else {
          _logger.info(status);
        }
        return ExitCode.success.code;
      }
      final report = await _check(
        paths: results.rest,
        gitDiff: ref,
        baseline: baselinePath,
      );
      final output = StringBuffer();
      _reporters[results.option('format')]!.write(report, output);
      _logger.write('$output');
      return _exitCode(report.failing);
    } on ConfigException catch (error) {
      _logger.err('$error');
      return ExitCode.config.code;
    } on BaselineException catch (error) {
      _logger.err('$error');
      return ExitCode.config.code;
    } on GitException catch (error) {
      _logger.err('$error');
      return ExitCode.software.code;
    }
  }

  /// Returns why [path] can't be checked, or `null` if it can.
  String? _invalidPath(String path) {
    final full = p.normalize(p.join(_root.path, path));
    if (!p.equals(full, _root.path) && !p.isWithin(_root.path, full)) {
      return 'Path `$path` is outside `${_root.path}`.';
    }
    if (!FileSystemEntity.isDirectorySync(full)) {
      return 'Path `$path` is not a directory.';
    }
    return null;
  }

  /// Returns [_violationsExitCode] if any of [violations] is an error, and 0
  /// otherwise.
  int _exitCode(List<Violation> violations) =>
      violations.any((v) => v.severity == Severity.error)
      ? _violationsExitCode
      : ExitCode.success.code;
}
