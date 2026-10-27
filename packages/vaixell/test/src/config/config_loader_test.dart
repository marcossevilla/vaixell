import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';

import '../../helpers/memory_source_tree.dart';

final Map<String, Severity> _recommended = Config.recommended().severities;

/// Returns [_recommended] with [overrides] applied, where `null` turns a rule
/// off.
Map<String, Severity> _recommendedWith(Map<String, Severity?> overrides) => {
  for (final MapEntry(:key, :value) in {..._recommended, ...overrides}.entries)
    key: ?value,
};

Future<Config> _load(String? yaml) =>
    ConfigLoader(MemorySourceTree({'analysis_options.yaml': ?yaml})).load();

void main() {
  group(ConfigLoader, () {
    group('valid config', () {
      final cases = <String, (String?, Map<String, Severity>)>{
        'no file': (null, _recommended),
        'an empty file': ('', _recommended),
        'a non-map file': ('- a\n', _recommended),
        'no vaixell key': ('linter:\n  rules: {}\n', _recommended),
        'an empty vaixell key': ('vaixell:\n', _recommended),
        'an empty vaixell map': ('vaixell: {}\n', _recommended),
        'include as a string': (
          'vaixell:\n  include: recommended\n',
          _recommended,
        ),
        'include as a list': (
          'vaixell:\n  include: [recommended, recommended]\n',
          _recommended,
        ),
        'an empty include list keeps parse-error': (
          'vaixell:\n  include: []\n',
          {'parse-error': Severity.error},
        ),
        'a rule turned off': (
          'vaixell:\n  rules:\n    top-level-function: off\n',
          _recommendedWith({'top-level-function': null}),
        ),
        'a rule set to warning': (
          'vaixell:\n  rules:\n    top-level-function: warning\n',
          _recommendedWith({'top-level-function': Severity.warning}),
        ),
        'parse-error set to warning': (
          'vaixell:\n  rules:\n    parse-error: warning\n',
          _recommendedWith({'parse-error': Severity.warning}),
        ),
        'a rule turned back on after an empty include': (
          'vaixell:\n  include: []\n  rules:\n    top-level-function: error\n',
          {'parse-error': Severity.error, 'top-level-function': Severity.error},
        ),
        'empty rules and exclude': (
          'vaixell:\n  rules:\n  exclude:\n',
          _recommended,
        ),
        'the analyzer include is ignored': (
          'include: package:very_good_analysis/analysis_options.yaml\n'
              'vaixell:\n  rules:\n    top-level-function: off\n',
          _recommendedWith({'top-level-function': null}),
        ),
      };
      for (final MapEntry(key: name, value: (yaml, severities))
          in cases.entries) {
        test(name, () async {
          expect((await _load(yaml)).severities, equals(severities));
        });
      }

      test('reads exclude globs', () async {
        final config = await _load(
          'vaixell:\n  exclude:\n    - lib/legacy/**\n    - "**/*.mapper.dart"\n',
        );
        expect(config.excludes('lib/legacy/a/b.dart'), isTrue);
        expect(config.excludes('lib/src/user.mapper.dart'), isTrue);
        expect(config.excludes('lib/src/a.dart'), isFalse);
      });

      test('loadIfPresent returns null without a vaixell key', () async {
        for (final files in [
          <String, String>{},
          {'analysis_options.yaml': ''},
          {'analysis_options.yaml': 'linter: {}\n'},
        ]) {
          expect(
            await ConfigLoader(MemorySourceTree(files)).loadIfPresent(),
            isNull,
            reason: '$files',
          );
        }
      });

      test('an empty vaixell key counts as present', () async {
        final tree = MemorySourceTree({
          'pkg/analysis_options.yaml': 'vaixell:\n',
        });
        final config = await ConfigLoader(
          tree,
          path: 'pkg/analysis_options.yaml',
        ).loadIfPresent();
        expect(config!.severities, equals(_recommended));
        expect(config.root, equals('pkg'));
      });

      test('exclude globs are relative to the config file', () async {
        final tree = MemorySourceTree({
          'pkg/analysis_options.yaml': 'vaixell:\n  exclude: [lib/legacy/**]\n',
        });
        final config = await ConfigLoader(
          tree,
          path: 'pkg/analysis_options.yaml',
        ).load();
        expect(config.root, equals('pkg'));
        expect(config.excludes('pkg/lib/legacy/a.dart'), isTrue);
        expect(config.excludes('pkg/lib/a.dart'), isFalse);
        expect(config.excludes('lib/legacy/a.dart'), isFalse);
        expect(config.excludes('pkg2/lib/legacy/a.dart'), isFalse);
      });

      test('reads only analysis_options.yaml', () async {
        final tree = MemorySourceTree({
          'analysis_options.yaml':
              'include: package:foo/analysis_options.yaml\n',
        });
        await ConfigLoader(tree).load();
        expect(tree.reads, equals(['analysis_options.yaml']));
      });

      test('reads from a custom path', () async {
        final tree = MemorySourceTree({
          'pkg/analysis_options.yaml': 'vaixell:\n  include: []\n',
        });
        final config = await ConfigLoader(
          tree,
          path: 'pkg/analysis_options.yaml',
        ).load();
        expect(config.severities.keys, equals(['parse-error']));
      });
    });

    group('invalid config', () {
      final cases = <String, (String, String)>{
        'invalid YAML': (
          'vaixell:\n  rules: [\n',
          'analysis_options.yaml:3:1: ',
        ),
        'a non-map vaixell key': (
          'vaixell: 1\n',
          'analysis_options.yaml:1:10: `vaixell` must be a map.',
        ),
        'an unknown key': (
          'vaixell:\n  rule: {}\n',
          'analysis_options.yaml:2:3: Unknown key `rule` under `vaixell`. '
              'Expected one of: include, rules, exclude.',
        ),
        'an unknown preset': (
          'vaixell:\n  include: strict\n',
          'analysis_options.yaml:2:12: Unknown preset `strict`. '
              'Available presets: recommended.',
        ),
        'an unknown preset in a list': (
          'vaixell:\n  include:\n    - recommended\n    - strict\n',
          'analysis_options.yaml:4:7: Unknown preset `strict`.',
        ),
        'a non-string include': (
          'vaixell:\n  include: {a: b}\n',
          'analysis_options.yaml:2:12: `include` must be a preset name or a '
              'list of preset names.',
        ),
        'non-map rules': (
          'vaixell:\n  rules: [a]\n',
          'analysis_options.yaml:2:10: `rules` must be a map of rule ids to '
              'severities.',
        ),
        'an unknown rule': (
          'vaixell:\n  rules:\n    no-globals: error\n',
          'analysis_options.yaml:3:5: Unknown rule `no-globals`. '
              'Available rules: parse-error, top-level-function, '
              'top-level-variable, extension-declaration, static-method, '
              'raw-json.',
        ),
        'an unknown severity': (
          'vaixell:\n  rules:\n    top-level-function: info\n',
          'analysis_options.yaml:3:25: Invalid severity `info` for '
              '`top-level-function`. Expected one of: off, warning, error.',
        ),
        'a boolean severity': (
          'vaixell:\n  rules:\n    top-level-function: false\n',
          'analysis_options.yaml:3:25: Invalid severity `false`',
        ),
        'parse-error turned off': (
          'vaixell:\n  rules:\n    parse-error: off\n',
          "analysis_options.yaml:3:18: `parse-error` can't be turned off.",
        ),
        'non-list exclude': (
          'vaixell:\n  exclude: lib/a.dart\n',
          'analysis_options.yaml:2:12: `exclude` must be a list of globs.',
        ),
        'a non-string exclude item': (
          'vaixell:\n  exclude: [1]\n',
          'analysis_options.yaml:2:13: `exclude` must be a list of globs.',
        ),
        'an invalid glob': (
          'vaixell:\n  exclude: ["lib/[a"]\n',
          'analysis_options.yaml:2:13: Invalid glob `lib/[a`: ',
        ),
      };
      for (final MapEntry(key: name, value: (yaml, message)) in cases.entries) {
        test(name, () async {
          await expectLater(
            _load(yaml),
            throwsA(
              isA<ConfigException>().having(
                (e) => e.toString(),
                'toString()',
                startsWith(message),
              ),
            ),
          );
        });
      }
    });
  });

  group(ConfigResolver, () {
    const off = 'vaixell:\n  rules:\n    top-level-function: off\n';
    const warning = 'vaixell:\n  rules:\n    top-level-function: warning\n';

    Future<Severity?> severityFor(
      Map<String, String> files,
      String package,
    ) async =>
        (await ConfigResolver(MemorySourceTree(files)).forPackage(package))
            .severities['top-level-function'];

    test('uses recommended without any config', () async {
      expect(await severityFor({}, 'packages/a'), equals(Severity.error));
    });

    test('uses the root config for members without one', () async {
      expect(
        await severityFor({'analysis_options.yaml': warning}, 'packages/a'),
        equals(Severity.warning),
      );
    });

    test("a member's config wins for that member only", () async {
      final files = {
        'analysis_options.yaml': warning,
        'packages/a/analysis_options.yaml': off,
      };
      expect(await severityFor(files, 'packages/a'), isNull);
      expect(await severityFor(files, 'packages/b'), equals(Severity.warning));
      expect(await severityFor(files, ''), equals(Severity.warning));
    });

    test('skips files without a vaixell key and never merges', () async {
      final files = {
        'analysis_options.yaml': 'vaixell:\n  exclude: [lib/gen/**]\n',
        'packages/analysis_options.yaml': warning,
        'packages/a/analysis_options.yaml': 'linter: {}\n',
      };
      final config = await ConfigResolver(MemorySourceTree(files))
          .forPackage('packages/a');
      expect(config.root, equals('packages'));
      expect(config.exclude, isEmpty);
      expect(config.severities['top-level-function'], equals(Severity.warning));
    });

    test('reads each file once', () async {
      final tree = MemorySourceTree({'analysis_options.yaml': warning});
      final resolver = ConfigResolver(tree);
      await resolver.forPackage('packages/a');
      await resolver.forPackage('packages/b');
      await resolver.forPackage('');
      expect(tree.reads, equals(['analysis_options.yaml']));
    });

    test("reports errors from a member's file", () async {
      final resolver = ConfigResolver(
        MemorySourceTree({
          'packages/a/analysis_options.yaml': 'vaixell:\n  nope: 1\n',
        }),
      );
      await expectLater(
        resolver.forPackage('packages/a'),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.toString(),
            'toString()',
            startsWith('packages/a/analysis_options.yaml:2:3: Unknown key'),
          ),
        ),
      );
    });
  });
}
