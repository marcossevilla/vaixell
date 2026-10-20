/// Checks architecture rules in Dart and Flutter repositories.
library;

export 'src/cli/theseus_command.dart' show TheseusCommand;
export 'src/config/config.dart' show Config, ConfigException;
export 'src/config/config_loader.dart' show ConfigLoader;
export 'src/engine/diff_result.dart' show DiffResult;
export 'src/engine/engine.dart' show Engine;
export 'src/engine/violation.dart' show Severity, Violation;
export 'src/git/git_runner.dart' show GitException, GitRunner;
export 'src/source/git_source_tree.dart' show GitSourceTree;
export 'src/source/source_tree.dart' show FileSystemSourceTree, SourceTree;
export 'src/version.dart' show TheseusVersion;
