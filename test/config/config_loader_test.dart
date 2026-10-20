import 'package:test/test.dart';
import 'package:theseus_cli/theseus_cli.dart';

import '../helpers/memory_source_tree.dart';

const Map<String, Severity> _recommended = {
  'parse-error': Severity.error,
  'top-level-function': Severity.error,
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
        'no theseus key': ('linter:\n  rules: {}\n', _recommended),
        'an empty theseus key': ('theseus:\n', _recommended),
        'an empty theseus map': ('theseus: {}\n', _recommended),
        'include as a string': (
          'theseus:\n  include: recommended\n',
          _recommended,
        ),
        'include as a list': (
          'theseus:\n  include: [recommended, recommended]\n',
          _recommended,
        ),
        'an empty include list keeps parse-error': (
          'theseus:\n  include: []\n',
          {'parse-error': Severity.error},
        ),
        'a rule turned off': (
          'theseus:\n  rules:\n    top-level-function: off\n',
          {'parse-error': Severity.error},
        ),
        'a rule set to warning': (
          'theseus:\n  rules:\n    top-level-function: warning\n',
          {
            'parse-error': Severity.error,
            'top-level-function': Severity.warning,
          },
        ),
        'parse-error set to warning': (
          'theseus:\n  rules:\n    parse-error: warning\n',
          {
            'parse-error': Severity.warning,
            'top-level-function': Severity.error,
          },
        ),
        'a rule turned back on after an empty include': (
          'theseus:\n  include: []\n  rules:\n    top-level-function: error\n',
          _recommended,
        ),
        'empty rules and exclude': (
          'theseus:\n  rules:\n  exclude:\n',
          _recommended,
        ),
        'the analyzer include is ignored': (
          'include: package:very_good_analysis/analysis_options.yaml\n'
              'theseus:\n  rules:\n    top-level-function: off\n',
          {'parse-error': Severity.error},
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
          'theseus:\n  exclude:\n    - lib/legacy/**\n    - "**/*.mapper.dart"\n',
        );
        expect(config.excludes('lib/legacy/a/b.dart'), isTrue);
        expect(config.excludes('lib/src/user.mapper.dart'), isTrue);
        expect(config.excludes('lib/src/a.dart'), isFalse);
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
          'pkg/analysis_options.yaml': 'theseus:\n  include: []\n',
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
          'theseus:\n  rules: [\n',
          'analysis_options.yaml:3:1: ',
        ),
        'a non-map theseus key': (
          'theseus: 1\n',
          'analysis_options.yaml:1:10: `theseus` must be a map.',
        ),
        'an unknown key': (
          'theseus:\n  rule: {}\n',
          'analysis_options.yaml:2:3: Unknown key `rule` under `theseus`. '
              'Expected one of: include, rules, exclude.',
        ),
        'an unknown preset': (
          'theseus:\n  include: strict\n',
          'analysis_options.yaml:2:12: Unknown preset `strict`. '
              'Available presets: recommended.',
        ),
        'an unknown preset in a list': (
          'theseus:\n  include:\n    - recommended\n    - strict\n',
          'analysis_options.yaml:4:7: Unknown preset `strict`.',
        ),
        'a non-string include': (
          'theseus:\n  include: {a: b}\n',
          'analysis_options.yaml:2:12: `include` must be a preset name or a '
              'list of preset names.',
        ),
        'non-map rules': (
          'theseus:\n  rules: [a]\n',
          'analysis_options.yaml:2:10: `rules` must be a map of rule ids to '
              'severities.',
        ),
        'an unknown rule': (
          'theseus:\n  rules:\n    no-globals: error\n',
          'analysis_options.yaml:3:5: Unknown rule `no-globals`. '
              'Available rules: parse-error, top-level-function.',
        ),
        'an unknown severity': (
          'theseus:\n  rules:\n    top-level-function: info\n',
          'analysis_options.yaml:3:25: Invalid severity `info` for '
              '`top-level-function`. Expected one of: off, warning, error.',
        ),
        'a boolean severity': (
          'theseus:\n  rules:\n    top-level-function: false\n',
          'analysis_options.yaml:3:25: Invalid severity `false`',
        ),
        'parse-error turned off': (
          'theseus:\n  rules:\n    parse-error: off\n',
          "analysis_options.yaml:3:18: `parse-error` can't be turned off.",
        ),
        'non-list exclude': (
          'theseus:\n  exclude: lib/a.dart\n',
          'analysis_options.yaml:2:12: `exclude` must be a list of globs.',
        ),
        'a non-string exclude item': (
          'theseus:\n  exclude: [1]\n',
          'analysis_options.yaml:2:13: `exclude` must be a list of globs.',
        ),
        'an invalid glob': (
          'theseus:\n  exclude: ["lib/[a"]\n',
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
}
