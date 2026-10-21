import 'dart:io';

import 'package:theseus_cli/src/engine/violation.dart';
import 'package:theseus_cli/src/report/report.dart';
import 'package:theseus_cli/src/report/reporter.dart';
import 'package:theseus_cli/src/report/text_reporter.dart';

/// Writes a [Report] for GitHub Actions.
///
/// Each failing violation (every violation in a full run, the new ones in
/// diff and baseline runs) becomes an `::error` or `::warning` workflow
/// command, which GitHub shows as an annotation on the file and line. GitHub
/// shows at most [maxAnnotations] of each severity per step, so violations
/// past that are printed as plain lines instead. A summary line follows.
///
/// When [summaryPath] is set, usually from `$GITHUB_STEP_SUMMARY`, a
/// markdown summary with the counts and tables of new and fixed violations
/// is appended to that file.
class GithubReporter implements Reporter {
  /// Creates a reporter that writes commands to [out] and appends the
  /// markdown summary to [summaryPath], if set.
  const new(this.out, {this.summaryPath});

  /// The number of annotations of each severity GitHub shows per step.
  static const int maxAnnotations = 10;

  /// Where the workflow commands are written.
  final StringSink out;

  /// The step summary file, or `null` to skip the summary.
  final String? summaryPath;

  @override
  void write(Report report) {
    final text = TextReporter(out);
    final counts = <Severity, int>{};
    var skipped = 0;
    for (final v in report.failing) {
      final count = counts.update(v.severity, (n) => n + 1, ifAbsent: () => 1);
      if (count <= maxAnnotations) {
        out.writeln(_annotation(v));
      } else {
        skipped++;
        out.writeln(text.describe(v));
      }
    }
    out.writeln(text.summary(report));
    final summaryPath = this.summaryPath;
    if (summaryPath != null) {
      File(summaryPath).writeAsStringSync(
        _markdown(report, text, skipped),
        mode: FileMode.append,
      );
    }
  }

  String _annotation(Violation v) =>
      '::${v.severity.name} '
      'file=${_property(v.path)},line=${v.line},col=${v.column},'
      'title=${_property('theseus ${v.rule}')}'
      '::${_data('${v.message} [${v.id}]')}';

  /// Escapes the message of a workflow command.
  String _data(String value) => value
      .replaceAll('%', '%25')
      .replaceAll('\r', '%0D')
      .replaceAll('\n', '%0A');

  /// Escapes a property value of a workflow command.
  String _property(String value) =>
      _data(value).replaceAll(':', '%3A').replaceAll(',', '%2C');

  String _markdown(Report report, TextReporter text, int skipped) {
    final buffer = StringBuffer()
      ..writeln('## theseus')
      ..writeln()
      ..writeln('**${text.summary(report)}** (${report.mode.name} mode)')
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
