/// Checks architecture rules in Dart and Flutter repositories.
library;

export 'src/baseline/baseline.dart'
    show Baseline, BaselineException, BaselineFile;
export 'src/check/check.dart' show Check;
export 'src/check/package_resolver.dart' show PackageResolver;
export 'src/check/write_baseline.dart' show WriteBaseline;
export 'src/command_runner.dart' show VaixellCommandRunner;
export 'src/commands/commands.dart' show CheckCommand, UpdateCommand;
export 'src/config/config.dart' show Config, ConfigException;
export 'src/config/config_loader.dart' show ConfigLoader, ConfigResolver;
export 'src/discovery/package_discovery.dart' show PackageDiscovery;
export 'src/engine/diff_result.dart' show DiffResult;
export 'src/engine/engine.dart' show Engine;
export 'src/engine/package.dart' show Package;
export 'src/git/git_runner.dart' show GitException, GitRunner;
export 'src/report/github_reporter.dart' show GithubReporter;
export 'src/report/json_reporter.dart' show JsonReporter;
export 'src/report/report.dart' show Report, ReportMode;
export 'src/report/reporter.dart' show Reporter;
export 'src/report/text_reporter.dart' show TextReporter;
export 'src/source/git_source_tree.dart' show GitSourceTree, OpenGitSourceTree;
export 'src/source/source_tree.dart' show FileSystemSourceTree, SourceTree;
export 'src/version.dart' show packageVersion;
export 'src/violation/violation.dart' show Severity, Violation;
