part of '../model.dart';

/// An annotation, `@prefix.name(arguments)`.
///
/// Without types, `@A.named()` reads as `name` `named` with `prefix` `A`.
abstract interface class Annotation {
  /// The last name before the arguments.
  String get name;

  /// The name before the dot, or `null` when there's none.
  String? get prefix;

  /// The arguments, in source order. Empty when there are no parentheses.
  List<Argument> get arguments;
}

/// An argument of an [Annotation] or a [Call].
abstract interface class Argument {
  /// The name, or `null` when positional.
  String? get name;

  /// The value.
  Expression get value;

  /// Whether [value] is a `bool`, number, `String` or `null` literal.
  bool get isLiteral;

  /// The value of the literal, when [isLiteral], otherwise `null`.
  Object? get literal;
}
