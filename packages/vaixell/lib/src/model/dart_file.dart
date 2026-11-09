part of 'model.dart';

/// A Dart file, parsed without type resolution.
abstract interface class DartFile {
  /// Parses [content] as the file at [path], a POSIX path relative to the
  /// repository root, without resolving types.
  ///
  /// The file is in the package at [packageRoot], relative to the repository
  /// root, where `''` is the root itself. [packageName] is the package's
  /// `pubspec.yaml` name, used to resolve imports of the package itself.
  factory parse({
    required String path,
    required String content,
    String packageRoot = '',
    String? packageName,
  }) => _AstDartFile(
    path,
    parseString(content: content, path: path, throwIfDiagnostics: false),
    packageRoot,
    packageName,
  );

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

  /// Every expression, at any depth, in source order.
  List<Expression> get expressions;

  /// Every type annotation, at any depth, including type arguments, in
  /// source order.
  List<TypeAnnotation> get typeAnnotations;

  /// The 1-based line of [offset].
  int lineAt(int offset);

  /// The 1-based column of [offset].
  int columnAt(int offset);
}
