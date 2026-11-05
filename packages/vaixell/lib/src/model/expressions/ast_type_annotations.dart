part of '../model.dart';

final class _AstTypeAnnotation(
  @override final _AstDartFile file,
  @override final ast.TypeAnnotation node,
) with _AstEnclosed implements TypeAnnotation {
  @override
  String? get name => switch (node) {
    ast.NamedType(:final name) => name.lexeme,
    _ => null,
  };

  @override
  String? get prefix => switch (node) {
    ast.NamedType(:final importPrefix?) => importPrefix.name.lexeme,
    _ => null,
  };

  @override
  late final List<TypeAnnotation> typeArguments = switch (node) {
    ast.NamedType(:final typeArguments?) => List.unmodifiable([
      for (final argument in typeArguments.arguments) file.type(argument),
    ]),
    _ => const [],
  };

  @override
  Cast? get cast => switch (node.parent) {
    final ast.AsExpression cast => file.expression(cast) as Cast,
    _ => null,
  };
}
