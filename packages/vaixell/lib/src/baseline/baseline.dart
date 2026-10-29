import 'dart:convert';
import 'dart:io';

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
  final Set<String> ids = {...ids};

  /// Returns the JSON for this baseline, with the ids sorted.
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'violations': ids.toList()..sort(),
  };
}

/// A problem reading a baseline file.
class const BaselineException(
  /// A description of the problem.
  final String message,
) implements Exception {
  /// Creates an exception with a [message] for the user.
  this;

  @override
  String toString() => message;
}

/// Reads and writes [Baseline] files.
class const BaselineFile() {
  /// Creates a handle for reading and writing baseline files.
  this;

  /// Reads the baseline at [path].
  ///
  /// Throws a [BaselineException] when the file is missing or malformed.
  Future<Baseline> read(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw BaselineException('Baseline file `$path` not found.');
    }
    try {
      return switch (const JsonDecoder().convert(await file.readAsString())) {
        final Map<String, Object?> json => Baseline.fromJson(json),
        _ => throw const FormatException('Expected a JSON object.'),
      };
    } on FormatException catch (error) {
      throw BaselineException(
        'Baseline file `$path` is malformed: ${error.message}',
      );
    }
  }

  /// Writes [baseline] to [path] as indented JSON with a trailing newline.
  Future<void> write(String path, Baseline baseline) => File(
    path,
  ).writeAsString('${const JsonEncoder.withIndent('  ').convert(baseline)}\n');
}
