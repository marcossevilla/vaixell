/// The `vaixell` command-line interface.
///
/// ```sh
/// dart pub global activate vaixell_cli
/// vaixell --help
/// ```
library;

export 'src/command_runner.dart' show VaixellCommandRunner;
export 'src/commands/commands.dart' show CheckCommand, UpdateCommand;
export 'src/version.dart' show packageVersion;
