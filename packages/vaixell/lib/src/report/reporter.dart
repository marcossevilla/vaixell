import 'package:vaixell/src/report/report.dart';

/// Writes a [Report] in one output format.
abstract interface class Reporter {
  /// Writes [report].
  void write(Report report);
}
