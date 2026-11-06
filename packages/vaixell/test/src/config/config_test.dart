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

final class const _ParseErrorRule() extends Rule {
  @override
  String get id => 'parse-error';
}

void main() {
  group(Config, () {
    test('recommended enables every rule at its default severity', () {
      final config = Config.recommended(RuleSet(Recommended.rules));
      expect(config.rules.map((r) => r.rule), Recommended.rules);
      expect(severitiesOf(config), {
        'parse-error': Severity.error,
        for (final rule in Recommended.rules) rule.id: rule.defaultSeverity,
      });
      expect(config.exclude, isEmpty);
      expect(config.excludes('lib/a.dart'), isFalse);
    });

    test('recommended leaves out entries that are not recommended', () {
      final config = Config.recommended(
        RuleSet([...Recommended.rules, const _OptInRule()]),
      );
      expect(config.rules.map((r) => r.rule.id), isNot(contains('opt-in')));
    });

    test('recommended builds factories without options', () {
      final factory = RuleFactory(
        'named',
        (options) => throw options['names'].error('Needs names.'),
      );
      expect(
        () => Config.recommended(RuleSet([factory]), root: 'pkg'),
        throwsA(
          isA<ConfigException>().having(
            (e) => '$e',
            'toString()',
            'pkg/analysis_options.yaml:1:1: Needs names.',
          ),
        ),
      );
    });

    test('recommended keeps the given root', () {
      expect(
        Config.recommended(RuleSet(Recommended.rules), root: 'pkg').root,
        'pkg',
      );
    });
  });

  group(RuleSet, () {
    test('keeps the rules in order', () {
      final reversed = Recommended.rules.reversed.toList();
      expect(RuleSet(reversed).entries, reversed);
    });

    test('lists parse-error, then each rule, as the ids config can name', () {
      expect(RuleSet(Recommended.rules).configIds, [
        'parse-error',
        for (final rule in Recommended.rules) rule.id,
      ]);
    });

    test('finds a rule by id', () {
      final rules = RuleSet(Recommended.rules);
      expect(
        rules['raw-json'],
        same(Recommended.rules.firstWhere((r) => r.id == 'raw-json')),
      );
      expect(rules['missing'], isNull);
    });

    test("can't be changed", () {
      final rules = RuleSet(Recommended.rules);
      expect(
        () => rules.entries.add(const _OptInRule()),
        throwsUnsupportedError,
      );
    });

    test('throws an ArgumentError for a repeated id', () {
      expect(
        () => RuleSet([...Recommended.rules, Recommended.rules.first]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Two rules have the id `top-level-function`.',
          ),
        ),
      );
    });

    test('throws an ArgumentError for a rule named parse-error', () {
      expect(
        () => RuleSet([...Recommended.rules, const _ParseErrorRule()]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            '`parse-error` is reported by the engine, not by a rule.',
          ),
        ),
      );
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
