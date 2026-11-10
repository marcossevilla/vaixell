import 'package:glob/glob.dart';
import 'package:mocktail/mocktail.dart';
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

final class const _NamedRule() extends Rule {
  @override
  String get id => 'named';
}

final class const _ParseErrorRule() extends Rule {
  @override
  String get id => 'parse-error';
}

class _MockOptionValue extends Mock implements OptionValue;

void main() {
  group(Config, () {
    group('configure', () {
      final options = _MockOptionValue();
      final rules = RuleSet([...Recommended.rules, const _OptInRule()]);

      test('enables the recommended rules by default', () {
        final config = Config.configure(rules, options: (_) => options);
        expect(config.rules.map((r) => r.rule), Recommended.rules);
        expect(config.parseErrorSeverity, Severity.error);
      });

      test('applies the given severities, where null is off', () {
        final config = Config.configure(
          rules,
          options: (_) => options,
          severities: {
            'parse-error': Severity.warning,
            'top-level-function': null,
            'raw-json': Severity.warning,
            'opt-in': Severity.error,
          },
        );
        final severities = severitiesOf(config);
        expect(severities['parse-error'], Severity.warning);
        expect(severities, isNot(contains('top-level-function')));
        expect(severities['raw-json'], Severity.warning);
        expect(severities['opt-in'], Severity.error);
      });

      test('only enables the set rules when not recommended', () {
        final config = Config.configure(
          rules,
          options: (_) => options,
          severities: const {'raw-json': Severity.error},
          recommended: false,
        );
        expect(config.rules.map((r) => r.rule.id), ['raw-json']);
      });

      test('builds each enabled rule once with the options for its id', () {
        final built = <String>[];
        final factory = RuleFactory('named', (given) {
          expect(given, same(options));
          return const _NamedRule();
        });
        Config.configure(
          RuleSet([factory, const _OptInRule()]),
          options: (id) {
            built.add(id);
            return options;
          },
        );
        expect(built, ['named']);
      });

      test('keeps the given exclude and root', () {
        final exclude = [Glob('lib/legacy/**')];
        final config = Config.configure(
          rules,
          options: (_) => options,
          exclude: exclude,
          root: 'pkg',
        );
        expect(config.exclude, same(exclude));
        expect(config.root, 'pkg');
      });
    });

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
        () => Config.recommended(RuleSet([factory])),
        throwsA(
          isA<ConfigException>().having(
            (e) => '$e',
            'toString()',
            'analysis_options.yaml:1:1: Needs names.',
          ),
        ),
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
}
