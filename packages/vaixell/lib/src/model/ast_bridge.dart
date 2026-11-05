part of 'model.dart';

/// Reaches the analyzer AST behind a [DartFile], for code that hasn't moved
/// to the model yet. Internal: it's never exported.
class const AstBridge() {
  /// Creates the bridge.
  this;

  /// The parse result that [file] wraps.
  ///
  /// [file] must come from [DartFileParser].
  ParseStringResult resultOf(DartFile file) => (file as _AstDartFile).result;

  /// The compilation unit that [file] wraps.
  ///
  /// [file] must come from [DartFileParser].
  ast.CompilationUnit unitOf(DartFile file) => resultOf(file).unit;
}
