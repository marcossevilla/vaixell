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
      final config = Config.recommended(builtInRules);
      expect(config.rules.map((r) => r.$1), builtInRules);
      expect(severitiesOf(config), {
        'parse-error': Severity.error,
        for (final rule in builtInRules) rule.id: rule.defaultSeverity,
      });
      expect(config.exclude, isEmpty);
      expect(config.excludes('lib/a.dart'), isFalse);
    });

    test('recommended leaves out entries that are not recommended', () {
      final config = Config.recommended([...builtInRules, const _OptInRule()]);
      expect(config.rules.map((r) => r.$1.id), isNot(contains('opt-in')));
    });

    test('recommended keeps the given root', () {
      expect(Config.recommended(builtInRules, root: 'pkg').root, 'pkg');
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
