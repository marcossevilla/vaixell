import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart';
import 'package:theseus_cli/src/config/config.dart';
import 'package:theseus_cli/src/config/config_loader.dart';
import 'package:theseus_cli/src/engine/diff_result.dart';
import 'package:theseus_cli/src/engine/engine.dart';
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
  /// Creates a command that checks the package in `root` (the current
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
      _stderr
        ..writeln('$unsupported is not supported yet.')
        ..writeln()
        ..writeln(usage);
      return ExitCode.usage.code;
    }

    final tree = FileSystemSourceTree(_root);
    final Config config;
    try {
      config = await ConfigLoader(tree).load();
    } on ConfigException catch (error) {
      _stderr.writeln(error);
      return ExitCode.config.code;
    }

    final ref = results.option('git-diff');
    if (ref == null) return await _full(tree, config);
    try {
      return await _diff(tree, config, ref);
    } on GitException catch (error) {
      _stderr.writeln(error);
      return ExitCode.software.code;
    }
  }

  Future<int> _full(SourceTree tree, Config config) async {
    final violations = await Engine(tree: tree, config: config).run();
    TextReporter(_stdout).report(violations);
    return _exitCode(violations);
  }

  /// Compares the working tree with the merge-base of [ref] and `HEAD`,
  /// checking both with the working tree's [config].
  Future<int> _diff(SourceTree head, Config config, String ref) async {
    final git = GitRunner(_root.path);
    final base = GitSourceTree(git: git, commit: await git.mergeBase(ref));
    final List<Violation> baseViolations;
    try {
      baseViolations = await Engine(tree: base, config: config).run();
    } finally {
      await base.close();
    }
    final diff = DiffResult.compare(
      base: baseViolations,
      head: await Engine(tree: head, config: config).run(),
    );
    TextReporter(_stdout).reportDiff(diff);
    return _exitCode(diff.added);
  }

  /// Returns 1 if any of [violations] is an error, and 0 otherwise.
  int _exitCode(List<Violation> violations) =>
      violations.any((v) => v.severity == Severity.error)
      ? 1
      : ExitCode.success.code;

  /// Returns a description of the first argument in [results] that is
  /// parsed but not implemented yet, or `null` if there is none.
  String? _unsupported(ArgResults results) {
    if (results.rest.isNotEmpty) return 'Passing paths';
    if (results.option('format') != 'text') {
      return '--format=${results.option('format')}';
    }
    for (final option in ['baseline', 'write-baseline']) {
      if (results.wasParsed(option)) return '--$option';
    }
    return null;
  }
}
