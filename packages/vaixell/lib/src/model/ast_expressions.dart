part of 'model.dart';

/// Lists every expression and type annotation in source order.
///
/// Names that are part of a larger node, such as `m` in `a.m()`, aren't
/// expressions of their own, so the visitor skips them. So it does the
/// function of a function declaration, and what isn't code: directives
/// other than their annotations, doc comment references and labels.
final class _AstCollector(final _AstDartFile file)
    extends GeneralizingAstVisitor<void> {
  final List<Expression> expressions = [];
  final List<TypeAnnotation> types = [];

  @override
  void visitExpression(ast.Expression node) {
    expressions.add(file.expression(node));
    super.visitExpression(node);
  }

  @override
  void visitTypeAnnotation(ast.TypeAnnotation node) {
    types.add(file.type(node));
    super.visitTypeAnnotation(node);
  }

  @override
  void visitMethodInvocation(ast.MethodInvocation node) {
    expressions.add(file.expression(node));
    node.target?.accept(this);
    node.typeArguments?.accept(this);
    node.argumentList.accept(this);
  }

  @override
  void visitPrefixedIdentifier(ast.PrefixedIdentifier node) {
    expressions.add(file.expression(node));
    node.prefix.accept(this);
  }

  @override
  void visitPropertyAccess(ast.PropertyAccess node) {
    expressions.add(file.expression(node));
    node.target?.accept(this);
  }

  @override
  void visitAnnotation(ast.Annotation node) {
    node.typeArguments?.accept(this);
    node.arguments?.accept(this);
  }

  @override
  void visitConstructorName(ast.ConstructorName node) => node.type.accept(this);

  /// A function declaration's function isn't an expression written in the
  /// code, so only its parts are.
  @override
  void visitFunctionExpression(ast.FunctionExpression node) {
    if (node.parent is ast.FunctionDeclaration) {
      node.visitChildren(this);
    } else {
      super.visitFunctionExpression(node);
    }
  }

  /// A directive's URIs and names aren't code, but its annotations are.
  @override
  void visitDirective(ast.Directive node) => node.metadata.accept(this);

  @override
  void visitComment(ast.Comment node) {}

  @override
  void visitLabel(ast.Label node) {}
}

/// Where an expression or type annotation is written.
mixin _AstEnclosed implements Enclosed {
  _AstDartFile get file;

  ast.AstNode get node;

  @override
  int get offset => node.offset;

  @override
  Declaration? get declaration => file.enclosing(node).declaration;

  @override
  Member? get member => file.enclosing(node).member;

  @override
  String? get symbol => file.symbolOf(declaration, member);
}

/// What every expression shares.
mixin _AstExpression on _AstEnclosed implements Expression {
  @override
  ast.Expression get node;

  @override
  Expression get unparenthesized => file.expression(node.unParenthesized);

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
  List<TypeAnnotation> get typeArguments => switch (node) {
    ast.NamedType(:final typeArguments?) => [
      for (final argument in typeArguments.arguments) file.type(argument),
    ],
    _ => const [],
  };

  @override
  Cast? get cast => switch (node.parent) {
    final ast.AsExpression cast => file.expression(cast) as Cast,
    _ => null,
  };
}
