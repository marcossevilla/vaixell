part of 'model.dart';

/// A Dart file, parsed without type resolution.
abstract interface class DartFile {
  /// The POSIX path, relative to the repository root.
  String get path;

  /// The path relative to the package root, for example `lib/src/a.dart`.
  String get packagePath;

  /// The directories of [path], for example `['lib', 'src', 'models']`.
  List<String> get directories;

  /// Syntax errors, in source order. Empty for every file a rule sees.
  List<SyntaxError> get errors;

  /// The `import` directives, in source order.
  List<Import> get imports;

  /// The top-level declarations, in source order, with one
  /// [TopLevelVariable] per declared name.
  List<Declaration> get declarations;
}
