part of '../model.dart';

final class _AstAwait(
  @override final _AstDartFile file,
  @override final ast.AwaitExpression node,
) with _AstEnclosed, _AstExpression implements Await {
  @override
  Expression get operand => file.expression(node.expression);
}

final class _AstMethodCall(
  @override final _AstDartFile file,
  @override final ast.MethodInvocation node,
) with _AstEnclosed, _AstExpression implements MethodCall {
  @override
  Expression? get target => file.expressionOrNull(node.realTarget);

  @override
  AccessOperator? get operator => file.accessOperator(node.operator);

  @override
  String get name => node.methodName.name;

  @override
  List<Argument> get arguments => file.arguments(node.argumentList);
}

final class _AstInstanceCreation(
  @override final _AstDartFile file,
  @override final ast.InstanceCreationExpression node,
) with _AstEnclosed, _AstExpression implements InstanceCreation {
  /// Without types, `new User.fromJson()` parses `User` as an import prefix
  /// and `fromJson` as the type, so the type's name can be the last name.
  @override
  String get name =>
      node.constructorName.name?.name ?? node.constructorName.type.name.lexeme;

  @override
  List<Argument> get arguments => file.arguments(node.argumentList);
}

final class _AstFunctionCall(
  @override final _AstDartFile file,
  @override final ast.FunctionExpressionInvocation node,
) with _AstEnclosed, _AstExpression implements FunctionCall {
  @override
  Expression get callee => file.expression(node.function);

  @override
  List<Argument> get arguments => file.arguments(node.argumentList);
}

/// `name`.
final class _AstIdentifier(
  @override final _AstDartFile file,
  @override final ast.SimpleIdentifier node,
) with _AstEnclosed, _AstExpression implements Reference {
  @override
  Expression? get target => null;

  @override
  AccessOperator? get operator => null;

  @override
  String get name => node.name;
}

/// `prefix.name`, which without types may be a property or an import prefix.
final class _AstPrefixedIdentifier(
  @override final _AstDartFile file,
  @override final ast.PrefixedIdentifier node,
) with _AstEnclosed, _AstExpression implements Reference {
  @override
  Expression get target => file.expression(node.prefix);

  @override
  AccessOperator get operator => AccessOperator.period;

  @override
  String get name => node.identifier.name;
}

/// `target.name`, `target?.name` or `..name`.
final class _AstPropertyAccess(
  @override final _AstDartFile file,
  @override final ast.PropertyAccess node,
) with _AstEnclosed, _AstExpression implements Reference {
  @override
  Expression get target => file.expression(node.realTarget);

  @override
  AccessOperator? get operator => file.accessOperator(node.operator);

  @override
  String get name => node.propertyName.name;
}

final class _AstCast(
  @override final _AstDartFile file,
  @override final ast.AsExpression node,
) with _AstEnclosed, _AstExpression implements Cast {
  @override
  Expression get operand => file.expression(node.expression);

  @override
  TypeAnnotation get type => file.type(node.type);
}

final class _AstNullCheck(
  @override final _AstDartFile file,
  @override final ast.PostfixExpression node,
) with _AstEnclosed, _AstExpression implements NullCheck {
  @override
  Expression get operand => file.expression(node.operand);
}

final class _AstThis(
  @override final _AstDartFile file,
  @override final ast.ThisExpression node,
) with _AstEnclosed, _AstExpression implements This;

final class _AstCollectionLiteral(
  @override final _AstDartFile file,
  @override final ast.TypedLiteral node,
) with _AstEnclosed, _AstExpression implements CollectionLiteral;

final class _AstParenthesized(
  @override final _AstDartFile file,
  @override final ast.ParenthesizedExpression node,
) with _AstEnclosed, _AstExpression implements Parenthesized {
  @override
  Expression get expression => file.expression(node.expression);
}

final class _AstOtherExpression(
  @override final _AstDartFile file,
  @override final ast.Expression node,
) with _AstEnclosed, _AstExpression implements OtherExpression;
