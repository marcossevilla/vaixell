import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';

import '../../helpers/severities.dart';

final class const _OptInRule() extends Rule {
  @override
  String get id => 'opt-in';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  bool get recommended => false;
}

void main() {
  group(Config, () {
    test('recommended enables every rule at its default severity', () {
      final config = Config.recommended(Recommended.rules);
      expect(config.rules.map((r) => r.rule), Recommended.rules);
      expect(severitiesOf(config), {
        'parse-error': Severity.error,
        for (final rule in Recommended.rules) rule.id: rule.defaultSeverity,
      });
      expect(config.exclude, isEmpty);
      expect(config.excludes('lib/a.dart'), isFalse);
    });

    test('recommended leaves out entries that are not recommended', () {
      final config = Config.recommended([
        ...Recommended.rules,
        const _OptInRule(),
      ]);
      expect(config.rules.map((r) => r.rule.id), isNot(contains('opt-in')));
    });

    test('recommended builds factories without options', () {
      final factory = RuleFactory(
        'named',
        (options) => throw options['names'].error('Needs names.'),
      );
      expect(
        () => Config.recommended([factory], root: 'pkg'),
        throwsA(
          isA<ConfigException>().having(
            (e) => '$e',
            'toString()',
            'pkg/analysis_options.yaml:1:1: Needs names.',
          ),
        ),
      );
    });

    test('recommended throws an ArgumentError for a repeated id', () {
      expect(
        () =>
            Config.recommended([...Recommended.rules, Recommended.rules.first]),
        throwsArgumentError,
      );
    });

    test('recommended keeps the given root', () {
      expect(Config.recommended(Recommended.rules, root: 'pkg').root, 'pkg');
    });
  });

  group(ConfigException, () {
    test('prints file:line:col and the message', () {
      const error = ConfigException(
        'Bad.',
        path: 'analysis_options.yaml',
        line: 3,
        column: 5,
      );
      expect(error.toString(), equals('analysis_options.yaml:3:5: Bad.'));
    });
  });
}
