part of '../model.dart';

/// An `import` directive. Its offset is the `import` keyword's and its
/// symbol is its [uri].
abstract interface class Import implements Reportable {
  /// The URI as written, for example `package:flutter/material.dart`, or
  /// `''` when it isn't a plain string.
  String get uri;

  /// Whether [uri] is a `dart:`, `package:` or relative URI.
  ImportKind get kind;

  /// The imported file, relative to the repository root, for relative
  /// imports and imports of the file's own package (by its `pubspec.yaml`
  /// name). `null` otherwise, and when the URI isn't a plain string.
  String? get path;
}

/// The kinds of [Import.uri].
enum ImportKind {
  /// A `dart:` URI.
  dart,

  /// A `package:` URI.
  package,

  /// A URI relative to the importing file.
  relative,
}
