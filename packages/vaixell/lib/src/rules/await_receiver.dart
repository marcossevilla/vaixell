import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vaixell/src/rules/enclosing_declaration.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Reports an `await` whose result is used as a receiver.
///
/// Flags `(await f).x`, `(await f)?.m()`, `(await f)[i]`, `(await f)..a()`
/// and `(await f)()`, looking through parentheses, `as` casts and `!`, so
/// `((await f) as T).x` and `(await f)!.x` are flagged too. Each `await` is
/// reported once, at the `await` keyword.
///
/// A null check on its own, as in `return (await f)!;`, is flagged unless
/// it is directly a variable initializer or the right side of an
/// assignment, so `final v = (await f)!;` is allowed. Awaits in conditions,
/// arguments and `return` or `=>` positions are allowed too.
///
/// Ids use the enclosing declaration, such as `ApiClient.getUser`.
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
    final (outermost, :nullChecked) = _outermost(node);
    if (_isReceiver(outermost) ||
        (nullChecked && !_isDeclarationOrAssignment(outermost))) {
      findings.add(
        Finding(
          offset: node.awaitKeyword.offset,
          message:
              '`await` result is used as a receiver. '
              'Assign it to a local variable first.',
          symbol: const EnclosingDeclaration().symbolOf(node),
        ),
      );
    }
    super.visitAwaitExpression(node);
  }

  /// Returns the outermost expression around [node] that only wraps it in
  /// parentheses, `as` casts or `!`, and whether a `!` was among them.
  (Expression, {bool nullChecked}) _outermost(Expression node) {
    var current = node;
    var nullChecked = false;
    while (true) {
      switch (current.parent) {
        case final ParenthesizedExpression parent:
          current = parent;
        case final AsExpression parent when parent.expression == current:
          current = parent;
        case final PostfixExpression parent when parent.operator.lexeme == '!':
          current = parent;
          nullChecked = true;
        default:
          return (current, nullChecked: nullChecked);
      }
    }
  }

  /// Whether [node] is directly a variable initializer or the right side of
  /// an assignment.
  bool _isDeclarationOrAssignment(Expression node) => switch (node.parent) {
    VariableDeclaration(:final initializer) => initializer == node,
    AssignmentExpression(:final rightHandSide) => rightHandSide == node,
    _ => false,
  };

  /// Whether [node] is the receiver of a member access, index, cascade or
  /// call.
  bool _isReceiver(Expression node) => switch (node.parent) {
    PropertyAccess(:final Expression? target) ||
    MethodInvocation(:final Expression? target) ||
    IndexExpression(:final Expression? target) ||
    CascadeExpression(:final Expression? target) => target == node,
    FunctionExpressionInvocation(:final function) => function == node,
    _ => false,
  };
}
