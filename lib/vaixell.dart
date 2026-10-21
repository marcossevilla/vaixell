/// Checks architecture rules in Dart and Flutter repositories.
library;

export 'src/baseline/baseline.dart'
    show Baseline, BaselineException, BaselineFile;
export 'src/cli/vaixell_command.dart' show VaixellCommand;
export 'src/config/config.dart' show Config, ConfigException;
export 'src/config/config_loader.dart' show ConfigLoader, ConfigResolver;
export 'src/discovery/package_discovery.dart' show PackageDiscovery;
export 'src/engine/diff_result.dart' show DiffResult;
export 'src/engine/engine.dart' show Engine;
export 'src/engine/package.dart' show Package;
export 'src/engine/violation.dart' show Severity, Violation;
export 'src/git/git_runner.dart' show GitException, GitRunner;
export 'src/report/github_reporter.dart' show GithubReporter;
export 'src/report/json_reporter.dart' show JsonReporter;
export 'src/report/report.dart' show Report, ReportMode;
export 'src/report/reporter.dart' show Reporter;
export 'src/report/text_reporter.dart' show TextReporter;
export 'src/source/git_source_tree.dart' show GitSourceTree;
export 'src/source/source_tree.dart' show FileSystemSourceTree, SourceTree;
export 'src/version.dart' show VaixellVersion;
