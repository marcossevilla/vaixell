import 'dart:io';
import 'dart:isolate';

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

    test('each rule and parse-error link to a docs page that exists', () {
      // `package:vaixell/` resolves to packages/vaixell/lib/, so the repo's
      // docs are three levels up, whatever directory the tests run from.
      final docs = Isolate.resolvePackageUriSync(Uri.parse('package:vaixell/'))!
          .resolve('../../../docs/rules/');
      for (final rule in Recommended.rules) {
        expect(rule, isA<BuiltInRule>(), reason: rule.id);
      }
      for (final id in [
        Config.parseErrorId,
        ...Recommended.rules.map((r) => r.id),
      ]) {
        expect(
          File.fromUri(docs.resolve('$id.md')).existsSync(),
          isTrue,
          reason: id,
        );
      }
    });
  });
}
