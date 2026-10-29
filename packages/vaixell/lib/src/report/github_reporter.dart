import 'dart:io';

import 'package:vaixell/src/report/report.dart';
import 'package:vaixell/src/report/reporter.dart';
import 'package:vaixell/src/report/text_reporter.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Writes a [Report] for GitHub Actions.
///
/// Each failing violation (every violation in a full run, the new ones in
/// diff and baseline runs) becomes an `::error` or `::warning` workflow
/// command, which GitHub shows as an annotation on the file and line. GitHub
/// shows at most [maxAnnotations] of each severity per step, so violations
/// past that are printed as plain lines instead. A summary line follows.
///
/// When [summaryPath] is set, usually from `$GITHUB_STEP_SUMMARY`, a
/// Markdown summary with the counts and tables of new and fixed violations
/// is appended to that file.
class GithubReporter(
  /// The sink that workflow commands are written to.
  final StringSink out, {

  /// The step summary file, or `null` to skip the summary.
  final String? summaryPath,
}) implements Reporter {
  /// Creates a reporter that writes commands to [out] and appends the
  /// Markdown summary to [summaryPath], if set.
  this;

  /// The number of annotations of each severity GitHub shows per step.
  static const int maxAnnotations = 10;

  final TextReporter _text = TextReporter(out);

  @override
  void write(Report report) {
    final counts = <Severity, int>{};
    var skipped = 0;
    for (final v in report.failing) {
      final count = counts.update(v.severity, (n) => n + 1, ifAbsent: () => 1);
      if (count <= maxAnnotations) {
        out.writeln(_annotation(v));
      } else {
        skipped++;
        out.writeln(_text.describe(v));
      }
    }
    out.writeln(_text.summary(report));
    final summaryPath = this.summaryPath;
    if (summaryPath != null) {
      File(summaryPath)
          .writeAsStringSync(_markdown(report, skipped), mode: FileMode.append);
    }
  }

  String _annotation(Violation v) =>
      '::${v.severity.name} '
      'file=${_property(v.path)},line=${v.line},col=${v.column},'
      'title=${_property('vaixell ${v.rule}')}'
      '::${_data('${v.message} [${v.id}]')}';

  /// Escapes the message of a workflow command.
  String _data(String value) => value
      .replaceAll('%', '%25')
      .replaceAll('\r', '%0D')
      .replaceAll('\n', '%0A');

  /// Escapes a property value of a workflow command.
  String _property(String value) =>
      _data(value).replaceAll(':', '%3A').replaceAll(',', '%2C');

  String _markdown(Report report, int skipped) {
    final buffer = StringBuffer()
      ..writeln('## vaixell')
      ..writeln()
      ..writeln('**${_text.summary(report)}** (${report.mode.name} mode)')
      ..writeln();
    final failing = report.failing;
    if (failing.isNotEmpty) {
      buffer
        ..writeln(report.diff == null ? '### Violations' : '### New violations')
        ..writeln()
        ..writeln('| Severity | Rule | File | Message |')
        ..writeln('| --- | --- | --- | --- |');
      for (final v in failing) {
        buffer.writeln(
          '| ${v.severity.name} | `${v.rule}` | '
          '`${v.path}:${v.line}:${v.column}` | ${_cell(v.message)} |',
        );
      }
      buffer.writeln();
    }
    final fixed = report.diff?.fixed ?? const [];
    if (fixed.isNotEmpty) {
      buffer
        ..writeln('### Fixed')
        ..writeln();
      for (final id in fixed) {
        buffer.writeln('- `$id`');
      }
      buffer.writeln();
    }
    if (skipped > 0) {
      buffer
        ..writeln(
          '> $skipped violation${skipped == 1 ? ' was' : 's were'} not '
          'annotated because GitHub shows at most $maxAnnotations errors '
          'and $maxAnnotations warnings per step. All of them are listed '
          'above.',
        )
        ..writeln();
    }
    return buffer.toString();
  }

  /// Escapes [value] for a markdown table cell.
  String _cell(String value) =>
      value.replaceAll('|', r'\|').replaceAll(RegExp(r'\s*\n\s*'), ' ');
}
