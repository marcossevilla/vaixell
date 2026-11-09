part of '../model.dart';

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
