import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;
import 'package:vaixell/src/baseline/baseline.dart';
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/config/config_loader.dart';
import 'package:vaixell/src/discovery/package_discovery.dart';
import 'package:vaixell/src/engine/diff_result.dart';
import 'package:vaixell/src/engine/engine.dart';
import 'package:vaixell/src/engine/package.dart';
import 'package:vaixell/src/engine/violation.dart';
import 'package:vaixell/src/git/git_runner.dart';
import 'package:vaixell/src/report/github_reporter.dart';
import 'package:vaixell/src/report/json_reporter.dart';
import 'package:vaixell/src/report/report.dart';
import 'package:vaixell/src/report/reporter.dart';
import 'package:vaixell/src/report/text_reporter.dart';
import 'package:vaixell/src/source/git_source_tree.dart';
import 'package:vaixell/src/source/source_tree.dart';
import 'package:vaixell/src/version.dart';

/// The `vaixell` command line interface.
///
/// Parses arguments and returns a process exit code that follows
/// `package:io`'s [ExitCode].
class VaixellCommand({
  required final StringSink _stdout,
  required final StringSink _stderr,
  Directory? root,
  Map<String, String>? environment,
}) {
  /// Creates a command that checks the packages in `root` (the current
  /// directory by default), writes the report to `stdout` and writes
  /// diagnostics to `stderr`.
  ///
  /// `environment` (the process environment by default) provides
  /// `GITHUB_STEP_SUMMARY` for `--format=github`.
  this;

  final Map<String, String> _environment = environment ?? Platform.environment;
  final Directory _root = root ?? Directory.current;

  final ArgParser _parser = ArgParser(usageLineLength: 80)
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag('version', negatable: false, help: 'Print the vaixell version.')
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
      'Usage: vaixell [options] [paths...]\n'
      '\n'
      'Checks the given package directories, or the packages found in the\n'
      'current directory: the workspace members, packages/* and pkgs/*.\n'
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
      _stdout.writeln(VaixellVersion.current);
      return ExitCode.success.code;
    }
    final ref = results.option('git-diff');
    final baselinePath = results.option('baseline');
    final writeBaselinePath = results.option('write-baseline');
    if (writeBaselinePath != null && (ref != null || baselinePath != null)) {
      return _usageError(
        '--write-baseline can not be combined with --git-diff or --baseline.',
      );
    }

    final invalidPath = results.rest.map(_invalidPath).nonNulls.firstOrNull;
    if (invalidPath != null) return _usageError(invalidPath);

    final format = results.option('format')!;
    final tree = FileSystemSourceTree(_root);
    try {
      final packages = await _packages(tree, results.rest);
      if (writeBaselinePath != null) {
        return await _writeBaseline(
          tree,
          packages,
          writeBaselinePath,
          // Keep stdout for the document in machine-readable formats.
          status: format == 'text' ? _stdout : _stderr,
        );
      }
      final baseline = baselinePath == null
          ? null
          : await BaselineFile(p.join(_root.path, baselinePath)).read();
      final violations = await Engine(tree: tree, packages: packages).run();

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
      _reporter(format).write(report);
      return _exitCode(report.failing);
    } on ConfigException catch (error) {
      _stderr.writeln(error);
      return ExitCode.config.code;
    } on BaselineException catch (error) {
      _stderr.writeln(error);
      return ExitCode.config.code;
    } on GitException catch (error) {
      _stderr.writeln(error);
      return ExitCode.software.code;
    }
  }

  /// Returns the package directories from the positional [paths], or the
  /// discovered ones when there are none, each with its nearest config.
  Future<List<Package>> _packages(SourceTree tree, List<String> paths) async {
    final dirs = paths.isEmpty
        ? await PackageDiscovery(tree).discover()
        : {for (final path in paths) _relative(path)}.toList();
    final resolver = ConfigResolver(tree);
    return [
      for (final dir in dirs)
        Package(path: dir, config: await resolver.forPackage(dir)),
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

  int _usageError(String message) {
    _stderr
      ..writeln(message)
      ..writeln()
      ..writeln(usage);
    return ExitCode.usage.code;
  }

  Future<int> _writeBaseline(
    SourceTree tree,
    List<Package> packages,
    String path, {
    required StringSink status,
  }) async {
    final violations = await Engine(tree: tree, packages: packages).run();
    final baseline = Baseline(violations.map((v) => v.id));
    await BaselineFile(p.join(_root.path, path)).write(baseline);
    final count = baseline.ids.length;
    status.writeln(
      'Wrote $count violation id${count == 1 ? '' : 's'} to $path.',
    );
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
      final baseViolations = await Engine(tree: base, packages: packages).run();
      return DiffResult.compare(
        base: baseViolations.map((v) => v.id),
        head: head,
      );
    } finally {
      await base.close();
    }
  }

  Reporter _reporter(String format) => switch (format) {
    'json' => JsonReporter(_stdout),
    'github' => GithubReporter(
      _stdout,
      summaryPath: switch (_environment['GITHUB_STEP_SUMMARY']) {
        '' => null,
        final path => path,
      },
    ),
    _ => TextReporter(_stdout),
  };

  /// Returns 1 if any of [violations] is an error, and 0 otherwise.
  int _exitCode(List<Violation> violations) =>
      violations.any((v) => v.severity == Severity.error)
      ? 1
      : ExitCode.success.code;
}
