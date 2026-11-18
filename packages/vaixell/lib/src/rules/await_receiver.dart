import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/built_in_rule.dart';
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
final class const AwaitReceiverRule()
    extends Rule
    with BuiltInRule, ChecksExpressions {
  /// Creates the rule.
  this;

  @override
  String get id => 'await-receiver';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Finding? checkExpression(Expression expression) => switch (expression) {
    Await(use: ReceiverUse() || NullCheckUse(), :final operand) => Finding.at(
      expression,
      qualifier: operand.calledName,
      message:
          '`await` result is used as a receiver. '
          'Assign it to a local variable first.',
    ),
    _ => null,
  };
}
