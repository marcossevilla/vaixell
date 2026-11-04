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
