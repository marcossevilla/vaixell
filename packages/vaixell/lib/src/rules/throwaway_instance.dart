import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Reports an instance created without arguments only to call a method or
/// read a getter on it, as in `const Parser().parse(source)`.
///
/// Flags `const Foo()`, `new Foo()`, `const Foo.named()` and `Foo()`
/// followed by `.` or `?.`, looking through parentheses. Without types,
/// `Foo.named()` can't be told apart from a static method or a factory such
/// as `DateTime.now()`, so it isn't reported unless it's `const` or `new`.
/// Cascades are allowed, since their value is the instance itself, and so
/// are constructors with arguments, whose instance carries that data.
///
/// Ids use the enclosing declaration and the name of the member, such as
/// `Config.recommended@check`.
final class const ThrowawayInstanceRule() extends Rule with ChecksExpressions {
  /// Creates the rule.
  this;

  @override
  String get id => 'throwaway-instance';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Finding? checkExpression(Expression expression) => switch (expression) {
    MethodCall(:final target?, :final operator, :final name) ||
    Reference(:final target?, :final operator, :final name)
        when _isAccess(operator) && _isThrowaway(target.unparenthesized) =>
      Finding.at(
        target.unparenthesized,
        qualifier: name,
        message:
            'An instance is created only to use `$name` on it. Move `$name` '
            'to the type whose data it works on, or take the instance as a '
            'dependency.',
      ),
    _ => null,
  };

  bool _isAccess(AccessOperator? operator) => switch (operator) {
    AccessOperator.period || AccessOperator.questionPeriod => true,
    _ => false,
  };

  bool _isThrowaway(Expression target) => switch (target) {
    InstanceCreation(arguments: []) => true,
    MethodCall(target: null, arguments: [], :final name) => _isTypeName(name),
    _ => false,
  };

  /// Whether [name] is written like a type, in UpperCamelCase, ignoring a
  /// leading `_` or `$`.
  bool _isTypeName(String name) =>
      switch (name.replaceFirst(RegExp(r'^[_$]+'), '')) {
        '' => false,
        final rest => rest[0] != rest[0].toLowerCase(),
      };
}
