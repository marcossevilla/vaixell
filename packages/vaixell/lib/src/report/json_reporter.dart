import 'dart:convert';

import 'package:vaixell/src/report/report.dart';
import 'package:vaixell/src/report/reporter.dart';

/// Writes a [Report] as one indented JSON document.
///
/// See [Report] for the schema.
class const JsonReporter(
  /// The sink that the document is written to.
  final StringSink out,
) implements Reporter {
  /// Creates a reporter that writes to [out].
  this;

  @override
  void write(Report report) =>
      out.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
