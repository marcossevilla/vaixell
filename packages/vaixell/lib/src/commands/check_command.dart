import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/baseline/baseline.dart';
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/config/config_loader.dart';
import 'package:vaixell/src/discovery/package_discovery.dart';
import 'package:vaixell/src/engine/diff_result.dart';
import 'package:vaixell/src/engine/engine.dart';
import 'package:vaixell/src/engine/package.dart';
import 'package:vaixell/src/git/git_runner.dart';
import 'package:vaixell/src/report/github_reporter.dart';
import 'package:vaixell/src/report/json_reporter.dart';
import 'package:vaixell/src/report/report.dart';
import 'package:vaixell/src/report/reporter.dart';
import 'package:vaixell/src/report/text_reporter.dart';
import 'package:vaixell/src/source/git_source_tree.dart';
import 'package:vaixell/src/source/source_tree.dart';
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
}) extends Command<int> {
  /// {@macro check_command}
  ///
  /// Checks the packages in [root] (the current directory by default). The
  /// report goes to stdout and diagnostics go to stderr, both through the
  /// logger.
  ///
  /// [environment] (the process environment by default) provides
  /// `GITHUB_STEP_SUMMARY` for `--format=github`.
  this {
    argParser
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
  }

  /// The name of this command.
  static const String commandName = 'check';

  /// The exit code when any reported violation is an error.
  static const int _violationsExitCode = 1;

  final Map<String, String> _environment = environment ?? Platform.environment;
  final Directory _root = root ?? Directory.current;

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

    final tree = FileSystemSourceTree(_root);
    try {
      final packages = await _packages(tree, results.rest);
      if (writeBaselinePath != null) {
        return await _writeBaseline(
          tree,
          packages,
          writeBaselinePath,
          // Keep stdout empty in machine-readable formats.
          toStderr: results.option('format') != 'text',
        );
      }
      final baseline = baselinePath == null
          ? null
          : await const BaselineFile().read(p.join(_root.path, baselinePath));
      final violations = await const Engine().run(
        tree: tree,
        packages: packages,
      );

      final Report report;
      if (ref != null) {
        final diff = await _gitDiff(violations, packages, ref);
        report = Report.compared(
          ReportMode.diff,
          violations,
          diff.suppress(baseline?.ids ?? const {}),
        );
      } else if (baseline != null) {
        report = Report.compared(
          ReportMode.baseline,
          violations,
          DiffResult.compare(base: baseline.ids, head: violations),
        );
      } else {
        report = Report.full(violations);
      }
      final output = StringBuffer();
      _reporter(results.option('format')!, output).write(report);
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

  /// Returns the package directories from the positional [paths], or the
  /// discovered ones when there are none, each with its nearest config.
  Future<List<Package>> _packages(SourceTree tree, List<String> paths) async {
    final dirs = paths.isEmpty
        ? await PackageDiscovery(tree).discover()
        : {for (final path in paths) _relative(path)}.toList();
    final configs = await ConfigResolver(ConfigLoader(tree)).forPackages(dirs);
    return [
      for (final (i, dir) in dirs.indexed)
        Package(path: dir, config: configs[i]),
    ];
  }

  /// Returns why [path] can't be checked, or `null` if it can.
  String? _invalidPath(String path) {
    final full = p.normalize(p.join(_root.path, path));
    if (!p.equals(full, _root.path) && !p.isWithin(_root.path, full)) {
      return 'Path `$path` is outside `${_root.path}`.';
    }
    if (!Directory(full).existsSync()) {
      return 'Path `$path` is not a directory.';
    }
    return null;
  }

  /// Returns [path] relative to the root, in POSIX style, where `''` is the
  /// root itself.
  String _relative(String path) {
    final relative = p.relative(p.join(_root.path, path), from: _root.path);
    return relative == '.' ? '' : p.posix.joinAll(p.split(relative));
  }

  Future<int> _writeBaseline(
    SourceTree tree,
    List<Package> packages,
    String path, {
    required bool toStderr,
  }) async {
    final violations = await const Engine().run(tree: tree, packages: packages);
    final baseline = Baseline(violations.map((v) => v.id));
    await const BaselineFile().write(p.join(_root.path, path), baseline);
    final count = baseline.ids.length;
    final status =
        'Wrote $count violation id${count == 1 ? '' : 's'} to $path.';
    if (toStderr) {
      _logger.warn(status, tag: '');
    } else {
      _logger.info(status);
    }
    return ExitCode.success.code;
  }

  /// Compares the [head] violations of the working tree with the merge-base
  /// of [ref] and `HEAD`, checking the same [packages], with the same
  /// configs, on both sides.
  Future<DiffResult> _gitDiff(
    List<Violation> head,
    List<Package> packages,
    String ref,
  ) async {
    final git = GitRunner(_root.path);
    final base = GitSourceTree(git: git, commit: await git.mergeBase(ref));
    try {
      final baseViolations = await const Engine().run(
        tree: base,
        packages: packages,
      );
      return DiffResult.compare(
        base: baseViolations.map((v) => v.id),
        head: head,
      );
    } finally {
      await base.close();
    }
  }

  Reporter _reporter(String format, StringSink output) => switch (format) {
    'json' => JsonReporter(output),
    'github' => GithubReporter(
      output,
      summaryPath: switch (_environment['GITHUB_STEP_SUMMARY']) {
        '' => null,
        final path => path,
      },
    ),
    _ => TextReporter(output),
  };

  /// Returns [_violationsExitCode] if any of [violations] is an error, and 0
  /// otherwise.
  int _exitCode(List<Violation> violations) =>
      violations.any((v) => v.severity == Severity.error)
      ? _violationsExitCode
      : ExitCode.success.code;
}
