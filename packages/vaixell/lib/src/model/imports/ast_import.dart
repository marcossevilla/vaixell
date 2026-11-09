part of '../model.dart';

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
    _ when node.uri.stringValue == null => null,
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
