import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/vaixell.dart';

/// {@template check_command}
/// `vaixell check`: checks architecture rules in the given packages.
///
/// Returns a process exit code that follows `package:io`'s [ExitCode].
/// {@endtemplate}
class CheckCommand._({
  required final Logger _logger,
  required final Directory _root,
  required final Check _check,
  required final WriteBaseline _writeBaseline,
  required final Map<String, Reporter> _reporters,
}) extends Command<int> {
  /// {@macro check_command}
  ///
  /// Checks the packages in [root] (the current directory by default) with
  /// [check], and writes baselines with [writeBaseline], both on [root] with
  /// [rules] by default. Given ones must check the same [root], which the
  /// paths are validated against. The report goes to stdout and diagnostics
  /// go to stderr, both through the logger.
  ///
  /// [reporters] maps each `--format` value to its [Reporter], and the first
  /// one is the default. It must not be empty. Formats other than a
  /// [TextReporter] keep stdout for the report alone. By default they're a
  /// [TextReporter], a [JsonReporter] and a [GithubReporter] whose summary
  /// is appended to `GITHUB_STEP_SUMMARY` from [environment] (the process
  /// environment by default).
  factory({
    required Logger logger,
    required List<RuleEntry> rules,
    Directory? root,
    Map<String, String>? environment,
    Check? check,
    WriteBaseline? writeBaseline,
    Map<String, Reporter>? reporters,
  }) {
    final dir = root ?? Directory.current;
    final summaryPath =
        (environment ?? Platform.environment)['GITHUB_STEP_SUMMARY'];
    return CheckCommand._(
      logger: logger,
      root: dir,
      check: check ?? Check(root: dir.path, rules: rules),
      writeBaseline:
          writeBaseline ?? WriteBaseline(root: dir.path, rules: rules),
      reporters:
          reporters ??
          {
            'text': const TextReporter(),
            'json': const JsonReporter(),
            'github': GithubReporter(
              writeSummary: summaryPath == null || summaryPath.isEmpty
                  ? null
                  : (markdown) =>
                        File(summaryPath)
                            .writeAsStringSync(markdown, mode: FileMode.append),
            ),
          },
    );
  }

  /// Adds the options for [_reporters], which must not be empty.
  this : assert(_reporters.isNotEmpty, 'reporters must not be empty') {
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
  static const int violationsExitCode = 1;

  /// Whether `--format` [format] keeps stdout for the report alone, which
  /// is every format but a [TextReporter]. A `null` [format] is the
  /// default one.
  bool isMachineReadable(String? format) =>
      _reporters[format ?? _reporters.keys.first] is! TextReporter;

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

    // `allowed` limits --format to the keys of _reporters.
    final reporter = _reporters[results.option('format')]!;
    try {
      if (writeBaselinePath != null) {
        return await _runWriteBaseline(
          writeBaselinePath,
          paths: results.rest,
          reporter: reporter,
        );
      }
      return await _runCheck(
        paths: results.rest,
        gitDiff: ref,
        baseline: baselinePath,
        reporter: reporter,
      );
    } on ConfigException catch (error) {
      return _fail(error, ExitCode.config);
    } on BaselineException catch (error) {
      return _fail(error, ExitCode.config);
    } on GitException catch (error) {
      return _fail(
        error,
        error.unavailable ? ExitCode.unavailable : ExitCode.data,
      );
    } on FileSystemException catch (error) {
      return _fail(
        '${error.message}${error.path == null ? '' : ': ${error.path}'}',
        ExitCode.ioError,
      );
    }
  }

  /// Logs [error] and returns [code].
  int _fail(Object error, ExitCode code) {
    _logger.err('$error');
    return code.code;
  }

  /// Writes the baseline of [paths] to [path] and logs the status, on stderr
  /// unless [reporter] is a [TextReporter].
  Future<int> _runWriteBaseline(
    String path, {
    required List<String> paths,
    required Reporter reporter,
  }) async {
    final baseline = await _writeBaseline(path, paths: paths);
    final count = baseline.ids.length;
    final status =
        'Wrote $count violation id${count == 1 ? '' : 's'} to $path.';
    // Keep stdout empty in machine-readable formats.
    if (reporter is TextReporter) {
      _logger.info(status);
    } else {
      // Unstyled on stderr: it's a status, not a warning.
      _logger.warn(status, tag: '', style: (message) => message);
    }
    return ExitCode.success.code;
  }

  /// Checks [paths] and writes the report with [reporter].
  Future<int> _runCheck({
    required List<String> paths,
    required String? gitDiff,
    required String? baseline,
    required Reporter reporter,
  }) async {
    final report = await _check(
      paths: paths,
      gitDiff: gitDiff,
      baseline: baseline,
    );
    final output = StringBuffer();
    reporter.write(report, output);
    _logger.write('$output');
    return _exitCode(report.failing);
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

  /// Returns [violationsExitCode] if any of [violations] is an error, and 0
  /// otherwise.
  int _exitCode(List<Violation> violations) =>
      violations.any((v) => v.severity == Severity.error)
      ? violationsExitCode
      : ExitCode.success.code;
}
