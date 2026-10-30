import 'dart:convert';

import 'package:vaixell/src/report/report.dart';
import 'package:vaixell/src/report/reporter.dart';

/// Writes a [Report] as one indented JSON document.
///
/// See [Report] for the schema.
class const JsonReporter() implements Reporter {
  /// Creates a reporter that writes JSON documents.
  this;

  @override
  void write(Report report, StringSink out) =>
      out.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
