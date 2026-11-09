part of '../model.dart';

/// A type annotation, such as `Map<String, dynamic>`.
///
/// A type annotation shared by several variables, as in
/// `Map<String, dynamic> a, b;`, is enclosed by the first.
abstract interface class TypeAnnotation implements Enclosed {
  /// The name, `null` for a function or record type.
  String? get name;

  /// The import prefix, as `core` in `core.Map`, or `null` when there's none.
  String? get prefix;

  /// The type arguments, in source order.
  List<TypeAnnotation> get typeArguments;

  /// The cast this is the type of, as in `x as Map<String, dynamic>`, or
  /// `null` when it isn't.
  Cast? get cast;
}
