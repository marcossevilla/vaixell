part of 'model.dart';

/// A syntax error reported by the parser. Its [symbol] is `null`.
abstract interface class SyntaxError implements Reportable {
  /// What the parser reported.
  String get message;
}
