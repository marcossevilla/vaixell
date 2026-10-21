import 'package:vaixell/src/config/config.dart';

/// A package to check and the config that applies to it.
class const Package({
  /// The package directory, relative to the repository root.
  required final String path,

  /// The rules, severities and excludes for this package.
  required final Config config,
}) {
  /// Creates a package at [path], relative to the repository root, where
  /// `''` is the root itself.
  this;
}
