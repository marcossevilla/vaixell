import 'dart:convert';
import 'dart:io';

import 'package:vaixell/src/baseline/baseline.dart';

/// The [Baseline] file at [path].
class const BaselineFile(
  /// The path of the file.
  final String path,
) {
  /// Creates a handle for the baseline file at [path].
  this;

  static const JsonDecoder _decoder = JsonDecoder();
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Reads the baseline.
  ///
  /// Throws a [BaselineException] when the file is missing, unreadable or
  /// malformed.
  Future<Baseline> read() async {
    final String content;
    try {
      content = await File(path).readAsString();
    } on PathNotFoundException {
      throw BaselineException('Baseline file `$path` not found.');
    } on FileSystemException catch (error) {
      throw BaselineException(
        'Could not read baseline file `$path`: ${error.message}.',
      );
    }
    try {
      return switch (_decoder.convert(content)) {
        final Map<String, Object?> json => Baseline.fromJson(json),
        _ => throw const FormatException('Expected a JSON object.'),
      };
    } on FormatException catch (error) {
      throw BaselineException(
        'Baseline file `$path` is malformed: ${error.message}',
      );
    }
  }

  /// Writes [baseline] as indented JSON with a trailing newline.
  ///
  /// Throws a [BaselineException] when the file can't be written, for
  /// example because its directory doesn't exist.
  Future<void> write(Baseline baseline) async {
    try {
      await File(path).writeAsString('${_encoder.convert(baseline)}\n');
    } on FileSystemException catch (error) {
      throw BaselineException(
        'Could not write baseline file `$path`: ${error.message}.',
      );
    }
  }
}
