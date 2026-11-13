import 'package:test/test.dart';
import 'package:vaixell/src/config/config_loader.dart';
import 'package:vaixell/vaixell.dart';

import '../../helpers/memory_source_tree.dart';
import '../../helpers/severities.dart';

/// The recommended severities, as a getter so each case gets its own map.
Map<String, Severity> get _recommended =>
    severitiesOf(Config.recommended(RuleSet(Recommended.rules)));

/// Returns [_recommended] with [overrides] applied, where `null` turns a rule
/// off.
Map<String, Severity> _recommendedWith(Map<String, Severity?> overrides) => {
  for (final MapEntry(:key, :value) in {..._recommended, ...overrides}.entries)
    key: ?value,
};

ConfigResolver _resolver(Map<String, String> files) => ConfigResolver(
  ConfigLoader(MemorySourceTree(files), RuleSet(Recommended.rules)),
);

/// The config in [yaml], or the recommended one without a `vaixell:` key,
/// as [ConfigResolver] picks it for the root.
Future<Config> _load(String? yaml) async {
  final rules = RuleSet(Recommended.rules);
  final config = await ConfigLoader(
    MemorySourceTree({'analysis_options.yaml': ?yaml}),
    rules,
  ).loadIfPresent();
  return config ?? Config.recommended(rules);
}

final class const _NamedRule(
  final List<String> names, {
  @override final String id = 'named',
}) extends Rule;

final class const _OptInRule() extends Rule {
  @override
  String get id => 'opt-in';

  @override
  bool get recommended => false;
}

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
        'a rule set to info': (
          'vaixell:\n  rules:\n    top-level-function: info\n',
          _recommendedWith({'top-level-function': Severity.info}),
        ),
        'parse-error set to warning': (
          'vaixell:\n  rules:\n    parse-error: warning\n',
          _recommendedWith({'parse-error': Severity.warning}),
        ),
        'parse-error set to info': (
          'vaixell:\n  rules:\n    parse-error: info\n',
          _recommendedWith({'parse-error': Severity.info}),
        ),
        'a rule turned back on after an empty include': (
          'vaixell:\n  include: []\n  rules:\n    top-level-function: error\n',
          {'parse-error': Severity.error, 'top-level-function': Severity.error},
        ),
        'empty rules and exclude': (
          'vaixell:\n  rules:\n  exclude:\n',
          _recommended,
        ),
        'a long-form severity': (
          'vaixell:\n  rules:\n    top-level-function:\n'
              '      severity: warning\n',
          _recommendedWith({'top-level-function': Severity.warning}),
        ),
        'a long form without severity enables at the default': (
          'vaixell:\n  include: []\n  rules:\n    top-level-function: {}\n',
          {'parse-error': Severity.error, 'top-level-function': Severity.error},
        ),
        'a long-form off': (
          'vaixell:\n  rules:\n    top-level-function: {severity: off}\n',
          _recommendedWith({'top-level-function': null}),
        ),
        'a long-form info': (
          'vaixell:\n  rules:\n    top-level-function: {severity: info}\n',
          _recommendedWith({'top-level-function': Severity.info}),
        ),
        'parse-error in the long form': (
          'vaixell:\n  rules:\n    parse-error: {severity: warning}\n',
          _recommendedWith({'parse-error': Severity.warning}),
        ),
        'parse-error set to info in the long form': (
          'vaixell:\n  rules:\n    parse-error: {severity: info}\n',
          _recommendedWith({'parse-error': Severity.info}),
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
          expect(severitiesOf(await _load(yaml)), equals(severities));
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

      group('loadIfPresent', () {
        test('returns null without a vaixell key', () async {
          for (final files in [
            <String, String>{},
            {'analysis_options.yaml': ''},
            {'analysis_options.yaml': 'linter: {}\n'},
          ]) {
            expect(
              await ConfigLoader(
                MemorySourceTree(files),
                RuleSet(Recommended.rules),
              ).loadIfPresent(),
              isNull,
              reason: '$files',
            );
          }
        });

        test('counts an empty vaixell key as present', () async {
          final tree = MemorySourceTree({
            'pkg/analysis_options.yaml': 'vaixell:\n',
          });
          final config = await ConfigLoader(
            tree,
            RuleSet(Recommended.rules),
          ).loadIfPresent(path: 'pkg/analysis_options.yaml');
          expect(severitiesOf(config!), equals(_recommended));
          expect(config.root, equals('pkg'));
        });
      });

      test('exclude globs are relative to the config file', () async {
        final tree = MemorySourceTree({
          'pkg/analysis_options.yaml': 'vaixell:\n  exclude: [lib/legacy/**]\n',
        });
        final config = (await ConfigLoader(
          tree,
          RuleSet(Recommended.rules),
        ).loadIfPresent(path: 'pkg/analysis_options.yaml'))!;
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
        await ConfigLoader(tree, RuleSet(Recommended.rules)).loadIfPresent();
        expect(tree.reads, equals(['analysis_options.yaml']));
      });

      test('reads from a custom path', () async {
        final tree = MemorySourceTree({
          'pkg/analysis_options.yaml': 'vaixell:\n  include: []\n',
        });
        final config = (await ConfigLoader(
          tree,
          RuleSet(Recommended.rules),
        ).loadIfPresent(path: 'pkg/analysis_options.yaml'))!;
        expect(severitiesOf(config).keys, equals(['parse-error']));
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
              'throwaway-instance, raw-json, generated-json, await-receiver.',
        ),
        'an unknown severity': (
          'vaixell:\n  rules:\n    top-level-function: hint\n',
          'analysis_options.yaml:3:25: Invalid severity `hint` for '
              '`top-level-function`. Expected one of: off, info, warning, '
              'error.',
        ),
        'a boolean severity': (
          'vaixell:\n  rules:\n    top-level-function: false\n',
          'analysis_options.yaml:3:25: Invalid severity `false`',
        ),
        'parse-error turned off': (
          'vaixell:\n  rules:\n    parse-error: off\n',
          "analysis_options.yaml:3:18: `parse-error` can't be turned off.",
        ),
        'options for a rule without options': (
          'vaixell:\n  rules:\n    top-level-function:\n      severity: error\n'
              '      names: [a]\n',
          'analysis_options.yaml:5:7: `top-level-function` takes no options.',
        ),
        'options for parse-error': (
          'vaixell:\n  rules:\n    parse-error: {x: 1}\n',
          'analysis_options.yaml:3:19: `parse-error` takes no options.',
        ),
        'an invalid long-form severity': (
          'vaixell:\n  rules:\n    top-level-function: {severity: hint}\n',
          'analysis_options.yaml:3:36: Invalid severity `hint` for '
              '`top-level-function`.',
        ),
        'parse-error turned off in the long form': (
          'vaixell:\n  rules:\n    parse-error: {severity: off}\n',
          "analysis_options.yaml:3:29: `parse-error` can't be turned off.",
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

    group('injected rules', () {
      Future<Config> load(String yaml, List<RuleEntry> rules) async =>
          (await ConfigLoader(
            MemorySourceTree({'analysis_options.yaml': yaml}),
            RuleSet(rules),
          ).loadIfPresent())!;

      test('an entry that is not recommended is off by default', () async {
        final config = await load('vaixell: {}\n', [
          ...Recommended.rules,
          const _OptInRule(),
        ]);
        expect(severitiesOf(config), isNot(contains('opt-in')));
        expect(severitiesOf(config), contains('top-level-function'));
      });

      test('an entry that is not recommended can be enabled by id', () async {
        final config = await load('vaixell:\n  rules:\n    opt-in: error\n', [
          ...Recommended.rules,
          const _OptInRule(),
        ]);
        expect(severitiesOf(config)['opt-in'], Severity.error);
        expect(config.rules.last.rule, isA<_OptInRule>());
      });

      test('a removed entry is an unknown rule', () async {
        await expectLater(
          load('vaixell:\n  rules:\n    raw-json: error\n', [
            for (final rule in Recommended.rules)
              if (rule.id != 'raw-json') rule,
          ]),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.message,
              'message',
              startsWith('Unknown rule `raw-json`.'),
            ),
          ),
        );
      });

      test('a factory builds its rule from the long form, once', () async {
        final given = <Map<String, OptionValue>>[];
        final factory = RuleFactory('named', (options) {
          given.add(options.asMap());
          return _NamedRule([
            for (final name in options['names'].asList()) name.asString(),
          ]);
        });
        final config = await load(
          'vaixell:\n  rules:\n    named:\n      severity: warning\n'
          '      names: [A, B]\n',
          [...Recommended.rules, factory],
        );
        expect(given.single.keys, ['names']);
        final ConfiguredRule(:rule, :severity) = config.rules.last;
        expect((rule as _NamedRule).names, ['A', 'B']);
        expect(severity, Severity.warning);
      });

      test('a factory enabled without options gets none', () async {
        final given = <OptionValue>[];
        final factory = RuleFactory('named', (options) {
          given.add(options);
          return const _NamedRule([]);
        }, recommended: false);
        for (final yaml in [
          'vaixell:\n  rules:\n    named: error\n',
          'vaixell:\n  rules:\n    named: {severity: error}\n',
        ]) {
          await load(yaml, [factory]);
        }
        expect(given.map((o) => o.asMap()), [isEmpty, isEmpty]);
      });

      test('a recommended factory is built without options', () async {
        var calls = 0;
        final factory = RuleFactory('named', (options) {
          calls++;
          expect(options.asMap(), isEmpty);
          return const _NamedRule([]);
        });
        final config = await load('vaixell: {}\n', [factory]);
        expect(config.rules.single.rule, isA<_NamedRule>());
        expect(calls, 1);
      });

      test('a factory that is off is not built', () async {
        final factory = RuleFactory(
          'named',
          (_) => fail('built'),
          recommended: false,
        );
        expect((await load('vaixell: {}\n', [factory])).rules, isEmpty);
      });

      test('reports option errors at their position', () async {
        final factory = RuleFactory('named', (options) {
          options.allowOnly({'names'});
          return const _NamedRule([]);
        });
        await expectLater(
          load('vaixell:\n  rules:\n    named:\n      nmes: [A]\n', [factory]),
          throwsA(
            isA<ConfigException>().having(
              (e) => '$e',
              'toString()',
              'analysis_options.yaml:4:7: Unknown key `nmes` under `named`. '
                  'Expected one of: names.',
            ),
          ),
        );
      });

      test('reports missing options at the rule', () async {
        final factory = RuleFactory(
          'named',
          (options) => _NamedRule([options['names'].asString()]),
          recommended: false,
        );
        for (final (yaml, position) in [
          ('vaixell:\n  rules:\n    named: error\n', '3:5'),
          ('vaixell:\n  rules:\n    named: {severity: error}\n', '3:12'),
        ]) {
          await expectLater(
            load(yaml, [factory]),
            throwsA(
              isA<ConfigException>().having(
                (e) => '$e',
                'toString()',
                'analysis_options.yaml:$position: `named` needs `names`.',
              ),
            ),
          );
        }
      });

      test('reports missing options of the preset at the section', () async {
        final factory = RuleFactory(
          'named',
          (options) => _NamedRule([options['names'].asString()]),
        );
        await expectLater(
          load('vaixell:\n  include: recommended\n', [factory]),
          throwsA(
            isA<ConfigException>().having(
              (e) => '$e',
              'toString()',
              'analysis_options.yaml:2:3: `named` needs `names`.',
            ),
          ),
        );
      });

      test('throws a StateError when a factory builds another rule', () async {
        final factory = RuleFactory(
          'named',
          (_) => const _NamedRule([], id: 'other'),
        );
        await expectLater(
          load('vaixell: {}\n', [factory]),
          throwsA(isA<StateError>()),
        );
      });

      test('the rules follow the order of the entries', () async {
        final reversed = Recommended.rules.reversed.toList();
        final config = await load('vaixell: {}\n', reversed);
        expect(config.rules.map((r) => r.rule), reversed);
      });
    });
  });

  group(ConfigResolver, () {
    test('builds factory rules once per config file', () async {
      var calls = 0;
      final factory = RuleFactory('named', (_) {
        calls++;
        return const _NamedRule([]);
      });
      final configs = await ConfigResolver(
        ConfigLoader(
          MemorySourceTree({'analysis_options.yaml': 'vaixell: {}\n'}),
          RuleSet([factory]),
        ),
      ).forPackages(['', 'packages/a', 'packages/b']);
      expect(configs, hasLength(3));
      expect(calls, 1);
    });

    const off = 'vaixell:\n  rules:\n    top-level-function: off\n';
    const warning = 'vaixell:\n  rules:\n    top-level-function: warning\n';

    Future<Severity?> severityFor(
      Map<String, String> files,
      String package,
    ) async => severitiesOf(
      (await _resolver(files).forPackages([package])).values.single,
    )['top-level-function'];

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
      final config = (await _resolver(files)
          .forPackages(['packages/a']))['packages/a']!;
      expect(config.root, equals('packages'));
      expect(config.exclude, isEmpty);
      expect(
        severitiesOf(config)['top-level-function'],
        equals(Severity.warning),
      );
    });

    test('reads each file once', () async {
      final tree = MemorySourceTree({'analysis_options.yaml': warning});
      final resolver = ConfigResolver(
        ConfigLoader(tree, RuleSet(Recommended.rules)),
      );
      final configs = await resolver.forPackages([
        'packages/a',
        'packages/b',
        '',
      ]);
      expect(configs, hasLength(3));
      expect(tree.reads, equals(['analysis_options.yaml']));
    });

    test('reads the files again on the next call', () async {
      final tree = MemorySourceTree({'analysis_options.yaml': warning});
      final resolver = ConfigResolver(
        ConfigLoader(tree, RuleSet(Recommended.rules)),
      );
      await resolver.forPackages(['packages/a']);
      tree.files['analysis_options.yaml'] = off;
      final config = (await resolver.forPackages([
        'packages/a',
      ]))['packages/a']!;
      expect(severitiesOf(config), isNot(contains('top-level-function')));
      expect(tree.reads, hasLength(2));
    });

    test("reports errors from a member's file", () async {
      final resolver = _resolver({
        'packages/a/analysis_options.yaml': 'vaixell:\n  nope: 1\n',
      });
      await expectLater(
        resolver.forPackages(['packages/a']),
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
