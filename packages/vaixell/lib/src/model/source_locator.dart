part of 'model.dart';

/// Finds lines and columns in [DartFile]s. Internal: it's never exported.
class const SourceLocator() {
  /// Creates the locator.
  this;

  /// The 1-based line and column of [offset] in [file].
  ///
  /// [file] must come from [DartFileParser].
  ({int line, int column}) locate(DartFile file, int offset) {
    final location = (file as _AstDartFile).result.lineInfo.getLocation(offset);
    return (line: location.lineNumber, column: location.columnNumber);
  }
}
