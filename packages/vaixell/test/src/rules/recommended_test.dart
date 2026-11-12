import 'dart:io';

import 'package:test/test.dart';
import 'package:vaixell/src/rules/built_in_rule.dart';
import 'package:vaixell/vaixell.dart';

void main() {
  group('Recommended.rules', () {
    test('lists every rule with a unique id, without parse-error', () {
      expect(Recommended.rules.map((r) => r.id), [
        'top-level-function',
        'top-level-variable',
        'extension-declaration',
        'static-method',
        'throwaway-instance',
        'raw-json',
        'generated-json',
        'await-receiver',
      ]);
    });

    test('each rule has the expected default severity', () {
      const warnings = {
        'throwaway-instance',
        'generated-json',
        'await-receiver',
      };
      for (final rule in Recommended.rules) {
        expect(
          rule.defaultSeverity,
          equals(
            warnings.contains(rule.id) ? Severity.warning : Severity.error,
          ),
          reason: rule.id,
        );
      }
    });

    test('are all recommended', () {
      expect(Recommended.rules.map((r) => r.recommended), everyElement(isTrue));
    });

    test('each rule links to its docs page', () {
      for (final rule in Recommended.rules) {
        expect(
          rule,
          isA<BuiltInRule>().having(
            (r) => '${r.docs}',
            'docs',
            'https://github.com/marcossevilla/vaixell/blob/main/docs/rules/'
                '${rule.id}.md',
          ),
        );
      }
    });

    test('each rule and parse-error have a docs page', () {
      for (final id in [
        Config.parseErrorId,
        ...Recommended.rules.map((r) => r.id),
      ]) {
        expect(
          File('../../docs/rules/$id.md').existsSync(),
          isTrue,
          reason: id,
        );
      }
    });
  });
}
