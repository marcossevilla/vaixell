part of 'model.dart';

/// A syntax error reported by the parser.
final class const SyntaxError(
  /// The character offset of the error in the file.
  final int offset,

  /// What the parser reported.
  final String message,
) {
  /// Creates the error the parser reported at [offset].
  this;
}
