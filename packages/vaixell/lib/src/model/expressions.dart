part of 'model.dart';

/// An expression or type annotation, and where it's written.
///
/// Its offset is where it starts, and its symbol is the symbol of its
/// [declaration] and [member], as in `Type.member`.
sealed class Enclosed implements Reportable {
  /// The top-level declaration it's in.
  ///
  /// `null` in a library directive's annotation, a top-level variable
  /// declaration's annotation, and typedefs, which the model doesn't have.
  Declaration? get declaration;

  /// The member of [declaration] it's in, or `null` when it's in the
  /// declaration itself, such as in its annotations or an enum value.
  Member? get member;
}

/// An expression.
///
/// The forms rules tell apart have their own type. The rest are
/// [OtherExpression]s, whose parts are still in [DartFile.expressions].
sealed class Expression implements Enclosed {
  /// How the value is used, looking through parentheses and `as` casts.
  Use get use;

  /// This expression without any parentheses around it.
  Expression get unparenthesized;
}

/// `await operand`.
abstract interface class Await implements Expression {
  /// What is awaited.
  Expression get operand;
}

/// Something called with an argument list.
sealed class Call implements Expression {
  /// The arguments, in source order.
  List<Argument> get arguments;
}

/// `name(…)`, `target.name(…)`, `target?.name(…)` or `..name(…)`.
///
/// Without types, `User(…)` and `User.fromJson(…)` are method calls too.
abstract interface class MethodCall implements Call {
  /// What [name] is called on, `null` for `name(…)`. In a cascade, the
  /// cascade's target.
  Expression? get target;

  /// How [name] is accessed on [target], `null` when there's no [target].
  AccessOperator? get operator;

  /// The name of what's called.
  String get name;
}

/// `new …(…)` or `const …(…)`.
abstract interface class InstanceCreation implements Call {
  /// The last name before the arguments: `fromJson` in
  /// `new User.fromJson(…)`, `User` in `const User()`.
  String get name;
}

/// Any other expression called, as in `(await f)()`.
abstract interface class FunctionCall implements Call {
  /// What's called.
  Expression get callee;
}

/// `name`, `target.name`, `target?.name` or `..name`.
abstract interface class Reference implements Expression {
  /// What [name] is read from, `null` for `name`. In a cascade, the
  /// cascade's target.
  Expression? get target;

  /// How [name] is accessed on [target], `null` when there's no [target].
  AccessOperator? get operator;

  /// The name.
  String get name;
}

/// How a [MethodCall] or [Reference] reaches its name.
enum AccessOperator {
  /// `.`
  period,

  /// `?.`
  questionPeriod,

  /// `..`
  cascade,

  /// `?..`
  questionCascade,
}

/// `operand as type`.
abstract interface class Cast implements Expression {
  /// What's cast.
  Expression get operand;

  /// The type it's cast to.
  TypeAnnotation get type;
}

/// `operand!`.
abstract interface class NullCheck implements Expression {
  /// What's null-checked.
  Expression get operand;
}

/// `this`.
abstract interface class This implements Expression;

/// A list, set or map literal.
abstract interface class CollectionLiteral implements Expression;

/// `(expression)`.
abstract interface class Parenthesized implements Expression {
  /// The expression in the parentheses.
  Expression get expression;
}

/// An expression of a form rules don't tell apart.
abstract interface class OtherExpression implements Expression;

/// How a value is used. See [Expression.use].
sealed class const Use() {
  /// Allows subclasses to be const.
  this;
}

/// The target of `.`, `?.`, `[]`, `?[]`, `..` or `?..`, or what's called
/// by `()`.
final class const ReceiverUse() extends Use {
  /// Creates the use.
  this;
}

/// The operand of `!`.
final class const NullCheckUse() extends Use {
  /// Creates the use.
  this;
}

/// An argument of a call.
final class const ArgumentUse(
  /// The call it's an argument of.
  final Call call, {

  /// The name of the argument, or `null` when it's positional.
  final String? name,
}) extends Use {
  /// Creates the use as an argument of [call].
  this;
}

/// Any other use.
final class const OtherUse() extends Use {
  /// Creates the use.
  this;
}
