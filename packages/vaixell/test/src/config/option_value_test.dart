import 'package:test/test.dart';
import 'package:vaixell/src/config/config.dart';
import 'package:vaixell/src/config/option_value.dart';
import 'package:yaml/yaml.dart';

const _path = 'analysis_options.yaml';

/// The options of `my-rule` in [yaml].
OptionValue _options(String yaml) => const OptionValues().of(
  loadYamlNode(yaml, sourceUrl: Uri.file(_path)),
  name: 'my-rule',
  path: _path,
);

/// Expects [read] to throw a [ConfigException] that prints as [message].
void _throws(Object? Function() read, String message) => expect(
  read,
  throwsA(isA<ConfigException>().having((e) => '$e', 'toString()', message)),
);

void main() {
  group(OptionValue, () {
    test('reads strings, lists and maps', () {
      final options = _options('a: x\nb: [y, z]\nc: {d: w}\n');
      expect(options['a'].asString(), 'x');
      expect(options['b'].asList().map((v) => v.asString()), ['y', 'z']);
      expect(options['c'].asMap().keys, ['d']);
      expect(options['c']['d'].asString(), 'w');
      expect(options.asMap().keys, ['a', 'b', 'c']);
    });

    group('throws positioned errors', () {
      final options = _options('a: 1\nb: [x, 2]\nc: x\nd: {e: [1]}\n');

      test('for a value that is not a string', () {
        _throws(
          () => options['a'].asString(),
          '$_path:1:4: `a` must be a string.',
        );
      });

      test('for a list item that is not a string', () {
        _throws(
          () => options['b'].asList()[1].asString(),
          '$_path:2:8: `b[1]` must be a string.',
        );
      });

      test('for a value that is not a list', () {
        _throws(() => options['c'].asList(), '$_path:3:4: `c` must be a list.');
      });

      test('for a value that is not a map', () {
        _throws(() => options['c'].asMap(), '$_path:3:4: `c` must be a map.');
        _throws(() => options['c']['x'], '$_path:3:4: `c` must be a map.');
      });

      test('naming nested values by their path', () {
        _throws(
          () => options['d']['e'].asList().single.asString(),
          '$_path:4:9: `d.e[0]` must be a string.',
        );
      });

      test('for a key that is not a string', () {
        _throws(
          () => _options('1: x\n').asMap(),
          '$_path:1:1: The keys of `my-rule` must be strings.',
        );
      });
    });

    group('a missing key', () {
      final options = _options('a: {b: x}\n');

      test('is reported by every reader, at the map', () {
        final missing = options['a']['c'];
        for (final read in <Object? Function()>[
          missing.asString,
          missing.asList,
          missing.asMap,
          () => missing['d'],
          () => missing.allowOnly({}),
        ]) {
          _throws(read, '$_path:1:4: `a` needs `c`.');
        }
      });

      test('of the rule is named after the rule', () {
        _throws(
          () => options['imports'].asList(),
          '$_path:1:1: `my-rule` needs `imports`.',
        );
      });
    });

    group('allowOnly', () {
      test('accepts known keys', () {
        expect(
          () => _options('a: 1\nb: 2\n').allowOnly({'a', 'b', 'c'}),
          returnsNormally,
        );
      });

      test('rejects other keys at the key', () {
        _throws(
          () => _options('a: 1\nzz: 2\n').allowOnly({'a', 'b'}),
          '$_path:2:1: Unknown key `zz` under `my-rule`. '
          'Expected one of: a, b.',
        );
      });

      test('names nested maps by their path', () {
        _throws(
          () => _options('a: {zz: 1}\n')['a'].allowOnly({'b'}),
          '$_path:1:5: Unknown key `zz` under `a`. Expected one of: b.',
        );
      });

      test('rejects values that are not maps', () {
        _throws(
          () => _options('a: x\n')['a'].allowOnly({'b'}),
          '$_path:1:4: `a` must be a map.',
        );
      });
    });

    test('builds errors at its position', () {
      final error = _options('a: x\n')['a'].error('Bad glob.');
      expect('$error', '$_path:1:4: Bad glob.');
    });
  });

  group(OptionValues, () {
    test('empty options are an empty map at the given position', () {
      final key = (loadYamlNode('\n  my-rule: error\n') as YamlMap).nodes.keys
          .cast<YamlNode>()
          .single;
      final options = const OptionValues().empty(
        key,
        name: 'my-rule',
        path: _path,
      );
      expect(options.asMap(), isEmpty);
      expect(() => options.allowOnly({}), returnsNormally);
      _throws(
        () => options['imports'].asList(),
        '$_path:2:3: `my-rule` needs `imports`.',
      );
    });
  });
}
