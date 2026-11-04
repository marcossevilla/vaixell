part of 'model.dart';

/// Something a finding can point at.
sealed class Reportable {
  /// The character offset in the file: the element's name, or its keyword
  /// when it has none.
  int get offset;

  /// What violation ids call the element, or `null` when it has no name.
  String? get symbol;
}

/// A syntax error reported by the parser. Its [symbol] is `null`.
abstract interface class SyntaxError implements Reportable {
  /// What the parser reported.
  String get message;
}
