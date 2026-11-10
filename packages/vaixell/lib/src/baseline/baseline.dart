/// A set of violation ids that a run doesn't report as new.
///
/// The file is JSON with sorted ids, so it gives stable git diffs:
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "violations": [
///     "top-level-function:lib/a.dart:foo"
///   ]
/// }
/// ```
class Baseline(Iterable<String> ids) {
  /// Creates a baseline with the violation [ids].
  this;

  /// Reads a baseline from its decoded JSON.
  ///
  /// Throws a [FormatException] when [json] doesn't match the schema.
  factory fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != schemaVersion) {
      throw FormatException(
        'Expected `schemaVersion` $schemaVersion, found $version.',
      );
    }
    return switch (json['violations']) {
      final List<Object?> ids when ids.every((id) => id is String) => Baseline(
        ids.cast<String>(),
      ),
      _ => throw const FormatException(
        '`violations` must be a list of violation ids.',
      ),
    };
  }

  /// The version of the file format.
  static const int schemaVersion = 1;

  /// The violation ids in the baseline.
  final Set<String> ids = Set.unmodifiable(ids);

  /// Returns the JSON for this baseline, with the ids sorted.
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'violations': ids.toList()..sort(),
  };
}

/// A problem reading or writing a baseline file.
class const BaselineException(
  /// A description of the problem.
  final String message,
) implements Exception {
  /// Creates an exception with a [message] for the user.
  this;

  @override
  String toString() => message;
}
