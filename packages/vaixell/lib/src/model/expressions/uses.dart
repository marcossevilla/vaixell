part of '../model.dart';

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
