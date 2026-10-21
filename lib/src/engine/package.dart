import 'package:theseus_cli/src/config/config.dart';

/// A package to check and the config that applies to it.
class Package {
  /// Creates a package at [path], relative to the repository root, where
  /// `''` is the root itself.
  const new({required this.path, required this.config});

  /// The package directory, relative to the repository root.
  final String path;

  /// The rules, severities and excludes for this package.
  final Config config;
}
