part of '../model.dart';

/// Where an expression or type annotation is written.
mixin _AstEnclosed implements Enclosed {
  _AstDartFile get file;

  ast.AstNode get node;

  @override
  int get offset => node.offset;

  late final ({Declaration? declaration, Member? member}) _enclosing = file
      .enclosing(node);

  @override
  Declaration? get declaration => _enclosing.declaration;

  @override
  Member? get member => _enclosing.member;

  @override
  late final String? symbol = file.symbolOf(declaration, member);
}

/// What every expression shares.
mixin _AstExpression on _AstEnclosed implements Expression {
  @override
  ast.Expression get node;

  @override
  Expression get unparenthesized => file.expression(node.unParenthesized);

  @override
  Expression get unwrapped => switch (this) {
    Parenthesized(:final expression) => expression.unwrapped,
    Cast(:final operand) || NullCheck(:final operand) => operand.unwrapped,
    _ => this,
  };

  @override
  String? get calledName => switch (unparenthesized) {
    MethodCall(:final name) || Reference(:final name) => name,
    FunctionCall(:final callee) => callee.calledName,
    _ => null,
  };

  @override
  bool isPositionalArgumentOf(String name) => switch (use) {
    ArgumentUse(
      name: null,
      call: MethodCall(name: final callName) ||
          InstanceCreation(name: final callName),
    ) =>
      callName == name,
    _ => false,
  };

  @override
  Use get use {
    ast.AstNode current = node;
    while (_wraps(current.parent, current)) {
      current = current.parent!;
    }
    return switch (current.parent) {
      ast.MethodInvocation(:final ast.Expression target) ||
      ast.PropertyAccess(:final ast.Expression target) ||
      ast.IndexExpression(:final ast.Expression target) ||
      ast.CascadeExpression(:final ast.Expression target) ||
      ast.FunctionExpressionInvocation(
        function: final ast.Expression target,
      ) when target == current => const ReceiverUse(),
      ast.PostfixExpression(operator: Token(type: TokenType.BANG)) =>
        const NullCheckUse(),
      ast.NamedArgument(:final name, :final parent?) => _argumentOf(
        parent,
        name: name.lexeme,
      ),
      final ast.ArgumentList list => _argumentOf(list),
      _ => const OtherUse(),
    };
  }

  /// Whether [parent] only wraps [child] in parentheses or a cast.
  ///
  /// Unlike [unwrapped], `!` doesn't count, since [use] reports it as a
  /// [NullCheckUse].
  bool _wraps(ast.AstNode? parent, ast.AstNode child) => switch (parent) {
    ast.ParenthesizedExpression() => true,
    ast.AsExpression(:final expression) => expression == child,
    _ => false,
  };

  Use _argumentOf(ast.AstNode list, {String? name}) => switch (list.parent) {
    final ast.Expression call
        when call is ast.MethodInvocation ||
            call is ast.InstanceCreationExpression ||
            call is ast.FunctionExpressionInvocation =>
      ArgumentUse(file.expression(call) as Call, name: name),
    _ => const OtherUse(),
  };
}
