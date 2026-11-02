import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vaixell/src/rules/enclosing_declaration.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Reports an `await` whose result is used as a receiver.
///
/// Flags `(await f).x`, `(await f)?.m()`, `(await f)[i]`, `(await f)..a()`,
/// `(await f)()` and `(await f)!`, looking through parentheses and `as`
/// casts, so `((await f) as T).x` is flagged too. Each `await` is reported
/// once, at the `await` keyword.
///
/// Awaits in conditions, arguments, initializers and `return` or `=>`
/// positions are allowed, as long as their result isn't dereferenced there.
///
/// Ids use the enclosing declaration and the name of the awaited call or
/// getter, such as `ApiClient.getUser@_fetch`, so adding or removing a
/// finding that awaits something else doesn't change them.
final class const AwaitReceiverRule() extends Rule {
  /// Creates the rule.
  this;

  @override
  String get id => 'await-receiver';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  List<Finding> check(ParsedFile file) {
    final visitor = _AwaitReceiverVisitor();
    file.unit.accept(visitor);
    return visitor.findings;
  }
}

class _AwaitReceiverVisitor extends RecursiveAstVisitor<void> {
  final List<Finding> findings = [];

  @override
  void visitAwaitExpression(AwaitExpression node) {
    if (_isReceiver(_outermost(node))) {
      findings.add(
        Finding(
          offset: node.awaitKeyword.offset,
          message:
              '`await` result is used as a receiver. '
              'Assign it to a local variable first.',
          symbol: _symbolOf(node),
        ),
      );
    }
    super.visitAwaitExpression(node);
  }

  /// Returns the enclosing declaration of [node], followed by `@` and the
  /// name of what it awaits when it has one.
  String? _symbolOf(AwaitExpression node) {
    final enclosing = const EnclosingDeclaration().symbolOf(node);
    return switch (_nameOf(node.expression)) {
      final name? => '${enclosing ?? ''}@$name',
      null => enclosing,
    };
  }

  /// Returns the name of the method, function, getter or variable that
  /// [expression] calls or reads, or `null` when it has none.
  String? _nameOf(Expression expression) =>
      switch (expression.unParenthesized) {
        MethodInvocation(:final methodName) => methodName.name,
        FunctionExpressionInvocation(:final function) => _nameOf(function),
        PropertyAccess(:final propertyName) => propertyName.name,
        PrefixedIdentifier(:final identifier) => identifier.name,
        SimpleIdentifier(:final name) => name,
        _ => null,
      };

  /// Returns the outermost expression around [node] that only wraps it in
  /// parentheses or `as` casts.
  Expression _outermost(Expression node) {
    var current = node;
    while (true) {
      switch (current.parent) {
        case final ParenthesizedExpression parent:
          current = parent;
        case final AsExpression parent when parent.expression == current:
          current = parent;
        default:
          return current;
      }
    }
  }

  /// Whether [node] is the receiver of a member access, index, cascade,
  /// call or null check.
  bool _isReceiver(Expression node) => switch (node.parent) {
    PropertyAccess(:final Expression? target) ||
    MethodInvocation(:final Expression? target) ||
    IndexExpression(:final Expression? target) ||
    CascadeExpression(:final Expression? target) => target == node,
    FunctionExpressionInvocation(:final function) => function == node,
    PostfixExpression(:final operator) => operator.lexeme == '!',
    _ => false,
  };
}
