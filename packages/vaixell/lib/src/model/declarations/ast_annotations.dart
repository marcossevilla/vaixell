part of '../model.dart';

final class _AstAnnotation(final _AstDartFile file, final ast.Annotation node)
    implements Annotation {
  @override
  String get name => switch (node.name) {
    ast.PrefixedIdentifier(:final identifier) => identifier.name,
    final name => name.name,
  };

  @override
  String? get prefix => switch (node.name) {
    ast.PrefixedIdentifier(:final prefix) => prefix.name,
    _ => null,
  };

  @override
  List<Argument> get arguments => file.arguments(node.arguments);

  @override
  Argument? argumentNamed(String name) =>
      arguments.where((argument) => argument.name == name).firstOrNull;
}

final class _AstArgument(final _AstDartFile file, final ast.Argument node)
    implements Argument {
  @override
  String? get name => switch (node) {
    ast.NamedArgument(:final name) => name.lexeme,
    _ => null,
  };

  @override
  Expression get value => file.expression(node.argumentExpression);

  @override
  bool get isLiteral => switch (node.argumentExpression) {
    ast.BooleanLiteral() ||
    ast.IntegerLiteral() ||
    ast.DoubleLiteral() ||
    ast.SimpleStringLiteral() ||
    ast.NullLiteral() => true,
    _ => false,
  };

  @override
  Object? get literal => switch (node.argumentExpression) {
    ast.BooleanLiteral(:final value) => value,
    ast.IntegerLiteral(:final value) => value,
    ast.DoubleLiteral(:final value) => value,
    ast.SimpleStringLiteral(:final value) => value,
    _ => null,
  };
}
