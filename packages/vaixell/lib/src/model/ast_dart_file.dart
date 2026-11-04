part of 'model.dart';

/// Builds [DartFile]s from source, without resolving types.
class const DartFileParser() {
  /// Creates the parser.
  this;

  /// Parses [content] as the file at [path], a POSIX path relative to the
  /// repository root.
  ///
  /// The file is in the package at [packageRoot], relative to the repository
  /// root, where `''` is the root itself. [packageName] is the package's
  /// `pubspec.yaml` name, used to resolve imports of the package itself.
  DartFile parse({
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
}

final class _AstDartFile(
  @override final String path,
  final ParseStringResult result,
  final String packageRoot,
  final String? packageName,
) implements DartFile {
  @override
  String get packagePath =>
      packageRoot.isEmpty ? path : p.posix.relative(path, from: packageRoot);

  @override
  List<String> get directories =>
      p.posix.split(p.posix.dirname(path))..remove('.');

  /// The parser doesn't report errors in source order, so they're sorted,
  /// keeping the parser's order among errors at the same offset.
  @override
  late final List<SyntaxError> errors = List.unmodifiable(
    (result.errors.indexed.toList()..sort(_bySourceOrder)).map(
      (entry) => _AstSyntaxError(entry.$2.offset, entry.$2.message),
    ),
  );

  static int _bySourceOrder((int, Diagnostic) a, (int, Diagnostic) b) =>
      switch (a.$2.offset.compareTo(b.$2.offset)) {
        0 => a.$1.compareTo(b.$1),
        final order => order,
      };

  @override
  late final List<Import> imports = List.unmodifiable([
    for (final directive in result.unit.directives)
      if (directive is ast.ImportDirective) _AstImport(this, directive),
  ]);
}

final class _AstSyntaxError(
  @override final int offset,
  @override final String message,
) implements SyntaxError {
  @override
  String? get symbol => null;
}

final class _AstImport(final _AstDartFile file, final ast.ImportDirective node)
    implements Import {
  @override
  int get offset => node.importKeyword.offset;

  @override
  String get uri => node.uri.stringValue ?? '';

  @override
  String get symbol => uri;

  @override
  ImportKind get kind => switch (uri) {
    _ when uri.startsWith('dart:') => ImportKind.dart,
    _ when uri.startsWith('package:') => ImportKind.package,
    _ => ImportKind.relative,
  };

  @override
  String? get path => switch ((kind, file.packageName)) {
    (ImportKind.relative, _) => p.posix.normalize(
      p.posix.join(p.posix.dirname(file.path), uri),
    ),
    (ImportKind.package, final name?) when uri.startsWith('package:$name/') =>
      p.posix.join(
        file.packageRoot,
        'lib',
        uri.substring('package:$name/'.length),
      ),
    _ => null,
  };
}
