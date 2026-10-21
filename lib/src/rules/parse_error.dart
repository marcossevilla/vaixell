import 'package:vaixell/src/rules/rule.dart';

/// Reports files that can't be parsed.
///
/// Other rules skip files with syntax errors, so this rule makes sure those
/// files still fail the run.
final class const ParseErrorRule() extends Rule {
  /// Creates the rule.
  this;

  @override
  String get id => 'parse-error';

  @override
  bool get checksFilesWithErrors => true;

  @override
  List<Finding> check(ParsedFile file) {
    final errors = file.result.errors;
    if (errors.isEmpty) return const [];
    final first = errors.first;
    final more = errors.length - 1;
    return [
      Finding(
        offset: first.offset,
        message:
            'Syntax error: ${first.message}'
            '${more > 0 ? ' (and $more more)' : ''}',
      ),
    ];
  }
}
