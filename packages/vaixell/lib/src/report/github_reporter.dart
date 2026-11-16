import 'package:vaixell/src/report/report.dart';
import 'package:vaixell/src/report/reporter.dart';
import 'package:vaixell/src/report/text_reporter.dart';
import 'package:vaixell/src/violation/violation.dart';

/// Writes a [Report] for GitHub Actions.
///
/// Each reported violation (every violation in a full run, the new ones in
/// diff and baseline runs) becomes an `::error`, `::warning` or `::notice`
/// (for [Severity.info]) workflow command, which GitHub shows as an
/// annotation on the file and line. GitHub shows at most [maxAnnotations] of
/// each per step, so violations past that are printed as plain lines
/// instead. A summary line follows.
///
/// When [writeSummary] is set, it gets a Markdown summary with the counts
/// and tables of new and fixed violations, usually to append to
/// `$GITHUB_STEP_SUMMARY`.
class const GithubReporter({
  /// Receives the Markdown step summary, or `null` to skip it.
  final void Function(String markdown)? writeSummary,
}) implements Reporter {
  /// Creates a reporter that passes the Markdown summary to [writeSummary],
  /// if set.
  this;

  /// The number of annotations of each severity GitHub shows per step.
  static const int maxAnnotations = 10;

  /// Formats the plain violation and summary lines.
  static const TextReporter _text = TextReporter();

  @override
  void write(Report report, StringSink out) {
    final counts = <Severity, int>{};
    var skipped = 0;
    for (final v in report.reported) {
      final count = counts.update(v.severity, (n) => n + 1, ifAbsent: () => 1);
      if (count <= maxAnnotations) {
        out.writeln(_annotation(v));
      } else {
        skipped++;
        out.writeln(_text.describe(v));
      }
    }
    out.writeln(_text.summary(report));
    writeSummary?.call(_markdown(report, skipped));
  }

  String _annotation(Violation v) =>
      '::${_command(v.severity)} '
      'file=${_property(v.path)},line=${v.line},col=${v.column},'
      'title=${_property('vaixell ${v.rule}')}'
      '::${_data('${v.message} [${v.id}]')}';

  /// The workflow command that annotates a violation of [severity].
  String _command(Severity severity) => switch (severity) {
    Severity.error => 'error',
    Severity.warning => 'warning',
    Severity.info => 'notice',
  };

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
    final reported = report.reported;
    if (reported.isNotEmpty) {
      buffer
        ..writeln(report.diff == null ? '### Violations' : '### New violations')
        ..writeln()
        ..writeln('| Severity | Rule | File | Message |')
        ..writeln('| --- | --- | --- | --- |');
      for (final v in reported) {
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
          'annotated because GitHub shows at most $maxAnnotations errors, '
          '$maxAnnotations warnings and $maxAnnotations notices per step. '
          'All of them are listed above.',
        )
        ..writeln();
    }
    return buffer.toString();
  }

  /// Escapes [value] for a markdown table cell.
  String _cell(String value) =>
      value.replaceAll('|', r'\|').replaceAll(RegExp(r'\s*\n\s*'), ' ');
}
