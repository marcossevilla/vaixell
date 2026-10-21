import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;
import 'package:theseus_cli/src/baseline/baseline.dart';
import 'package:theseus_cli/src/config/config.dart';
import 'package:theseus_cli/src/config/config_loader.dart';
import 'package:theseus_cli/src/discovery/package_discovery.dart';
import 'package:theseus_cli/src/engine/diff_result.dart';
import 'package:theseus_cli/src/engine/engine.dart';
import 'package:theseus_cli/src/engine/package.dart';
import 'package:theseus_cli/src/engine/violation.dart';
import 'package:theseus_cli/src/git/git_runner.dart';
import 'package:theseus_cli/src/report/text_reporter.dart';
import 'package:theseus_cli/src/source/git_source_tree.dart';
import 'package:theseus_cli/src/source/source_tree.dart';
import 'package:theseus_cli/src/version.dart';

/// The `theseus` command line interface.
///
/// Parses arguments and returns a process exit code that follows
/// `package:io`'s [ExitCode].
class TheseusCommand {
  /// Creates a command that checks the packages in `root` (the current
  /// directory by default), writes the report to `stdout` and writes
  /// diagnostics to `stderr`.
  new({required this._stdout, required this._stderr, Directory? root})
    : _root = root ?? Directory.current;

  final StringSink _stdout;
  final StringSink _stderr;
  final Directory _root;

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
      _stdout.writeln(TheseusVersion.current);
      return ExitCode.success.code;
    }
    final unsupported = _unsupported(results);
    if (unsupported != null) {
      return _usageError('$unsupported is not supported yet.');
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

    final tree = FileSystemSourceTree(_root);
    try {
      final packages = await _packages(tree, results.rest);
      if (writeBaselinePath != null) {
        return await _writeBaseline(tree, packages, writeBaselinePath);
      }
      final baseline = baselinePath == null
          ? null
          : await BaselineFile(p.join(_root.path, baselinePath)).read();
      final violations = await Engine(tree: tree, packages: packages).run();

      final DiffResult diff;
      if (ref != null) {
        diff = (await _gitDiff(
          violations,
          packages,
          ref,
        )).suppress(baseline?.ids ?? const {});
      } else if (baseline != null) {
        diff = DiffResult.compare(base: baseline.ids, head: violations);
      } else {
        TextReporter(_stdout).report(violations);
        return _exitCode(violations);
      }
      TextReporter(_stdout).reportDiff(diff);
      return _exitCode(diff.added);
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
    String path,
  ) async {
    final violations = await Engine(tree: tree, packages: packages).run();
    final baseline = Baseline(violations.map((v) => v.id));
    await BaselineFile(p.join(_root.path, path)).write(baseline);
    final count = baseline.ids.length;
    _stdout.writeln(
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

  /// Returns 1 if any of [violations] is an error, and 0 otherwise.
  int _exitCode(List<Violation> violations) =>
      violations.any((v) => v.severity == Severity.error)
      ? 1
      : ExitCode.success.code;

  /// Returns a description of the first argument in [results] that is
  /// parsed but not implemented yet, or `null` if there is none.
  String? _unsupported(ArgResults results) {
    if (results.option('format') != 'text') {
      return '--format=${results.option('format')}';
    }
    return null;
  }
}
