import 'package:vaixell/src/config/config.dart';

/// A package to check and the config that applies to it.
class const Package({
  /// The package directory, relative to the repository root.
  required final String path,

  /// The rules, severities and excludes for this package.
  required final Config config,

  /// The `name` in the package's `pubspec.yaml`, or `null` when there's
  /// none. Imports of the package by this name resolve to its files.
  final String? name,
}) {
  /// Creates a package at [path], relative to the repository root, where
  /// `''` is the root itself.
  this;
}
