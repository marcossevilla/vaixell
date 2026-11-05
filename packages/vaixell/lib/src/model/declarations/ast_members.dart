part of '../model.dart';

final class _AstMethod(
  final _AstDartFile file,
  final ast.MethodDeclaration node,
) implements Method {
  @override
  late final String? symbol = file.symbolOf(
    file.enclosing(node).declaration,
    this,
  );

  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;

  @override
  FunctionKind get kind => file.kind(
    isGetter: node.isGetter,
    isSetter: node.isSetter,
    isOperator: node.isOperator,
  );

  @override
  bool get isStatic => node.isStatic;

  @override
  bool get isAbstract => node.body is ast.EmptyFunctionBody;

  @override
  bool get isExternal => node.externalKeyword != null;

  @override
  List<Parameter> get parameters => file.parameters(node.parameters);

  @override
  Expression? get returnExpression => file.returnExpression(node.body);
}

final class _AstConstructor(
  final _AstDartFile file,
  final ast.ConstructorDeclaration node,
) implements Constructor {
  @override
  late final String? symbol = file.symbolOf(
    file.enclosing(node).declaration,
    this,
  );

  @override
  String? get name => node.name?.lexeme;

  /// The name, or the type name, `new` or `factory` when it's unnamed.
  @override
  int get offset =>
      (node.name ??
              node.typeName?.token ??
              node.newKeyword ??
              node.factoryKeyword)!
          .offset;

  @override
  bool get isFactory => node.factoryKeyword != null;

  @override
  bool get isExternal => node.externalKeyword != null;

  @override
  List<Parameter> get parameters => file.parameters(node.parameters);

  @override
  Expression? get returnExpression => file.returnExpression(node.body);
}

final class _AstField(
  final _AstDartFile file,
  final ast.VariableDeclaration node,
) implements Field {
  @override
  late final String? symbol = file.symbolOf(
    file.enclosing(node).declaration,
    this,
  );

  @override
  String get name => node.name.lexeme;

  @override
  int get offset => node.name.offset;

  @override
  bool get isStatic => (node.parent!.parent! as ast.FieldDeclaration).isStatic;
}

final class _AstParameter(final ast.FormalParameter node) implements Parameter {
  @override
  String? get name => node.name?.lexeme;

  @override
  bool get isPositional => node.isPositional;

  @override
  bool get isNamed => node.isNamed;

  @override
  bool get isFunction =>
      node.functionTypedSuffix != null || node.type is ast.GenericFunctionType;
}
