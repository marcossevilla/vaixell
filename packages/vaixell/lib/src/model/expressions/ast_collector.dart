part of '../model.dart';

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

  /// A name that's part of a larger node, such as `m` in `a.m()` or `x` in
  /// a constructor's `: x = 1`, isn't an expression of its own.
  @override
  void visitSimpleIdentifier(ast.SimpleIdentifier node) {
    if (!_isNameOf(node.parent, node)) super.visitSimpleIdentifier(node);
  }

  bool _isNameOf(ast.AstNode? parent, ast.SimpleIdentifier node) =>
      switch (parent) {
        ast.MethodInvocation(methodName: final name) ||
        ast.PrefixedIdentifier(identifier: final name) ||
        ast.PropertyAccess(propertyName: final name) ||
        ast.ConstructorDeclaration(typeName: final name?) ||
        ast.ConstructorFieldInitializer(fieldName: final name) ||
        ast.SuperConstructorInvocation(constructorName: final name?) ||
        ast.RedirectingConstructorInvocation(constructorName: final name?) ||
        ast.ConstructorSelector(:final name) ||
        ast.DotShorthandInvocation(memberName: final name) ||
        ast.DotShorthandPropertyAccess(propertyName: final name) ||
        ast.DotShorthandConstructorInvocation(
          constructorName: final name,
        ) => name == node,
        _ => false,
      };

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
