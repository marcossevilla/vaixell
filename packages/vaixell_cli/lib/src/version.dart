/// The published name and version of the CLI.
abstract final class CliPackage {
  /// The name of the package on pub.dev, used to check for updates.
  static const String name = 'vaixell_cli';

  /// The current version of the CLI, kept in sync with `pubspec.yaml` by
  /// release-please.
  static const String version = '0.1.0'; // x-release-please-version
}
