import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:theseus_cli/theseus_cli.dart';

void main() {
  group(Baseline, () {
    test('toJson sorts and dedupes the ids', () {
      expect(
        Baseline(['b', 'a', 'b']).toJson(),
        equals({
          'schemaVersion': 1,
          'violations': ['a', 'b'],
        }),
      );
    });

    test('fromJson reads the ids', () {
      final baseline = Baseline.fromJson({
        'schemaVersion': 1,
        'violations': ['a', 'b'],
      });
      expect(baseline.ids, equals({'a', 'b'}));
    });

    for (final (name, json, message) in [
      (
        'a missing version',
        <String, Object?>{'violations': <Object?>[]},
        'Expected `schemaVersion` 1, found null.',
      ),
      (
        'another version',
        {'schemaVersion': 2, 'violations': <Object?>[]},
        'Expected `schemaVersion` 1, found 2.',
      ),
      (
        'missing violations',
        {'schemaVersion': 1},
        '`violations` must be a list of violation ids.',
      ),
      (
        'non-string ids',
        {
          'schemaVersion': 1,
          'violations': [1],
        },
        '`violations` must be a list of violation ids.',
      ),
    ]) {
      test('fromJson rejects $name', () {
        expect(
          () => Baseline.fromJson(json),
          throwsA(
            isA<FormatException>().having((e) => e.message, 'message', message),
          ),
        );
      });
    }
  });

  group(BaselineFile, () {
    late String path;

    setUp(() => path = d.path('baseline.json'));

    test('writes deterministic, indented JSON and reads it back', () async {
      await BaselineFile(path).write(Baseline(['b', 'a']));
      expect(
        File(path).readAsStringSync(),
        equals(
          '{\n'
          '  "schemaVersion": 1,\n'
          '  "violations": [\n'
          '    "a",\n'
          '    "b"\n'
          '  ]\n'
          '}\n',
        ),
      );
      expect((await BaselineFile(path).read()).ids, equals({'a', 'b'}));
    });

    Matcher baselineError(Object message) => throwsA(
      isA<BaselineException>().having(
        (e) => e.toString(),
        'toString()',
        message,
      ),
    );

    test('throws when the file is missing', () async {
      await expectLater(
        BaselineFile(path).read(),
        baselineError('Baseline file `$path` not found.'),
      );
    });

    for (final (name, content, detail) in [
      ('invalid JSON', '{', 'Unexpected end of input'),
      ('a non-object', '[]', 'Expected a JSON object.'),
      (
        'an invalid schema',
        '{"schemaVersion": 1}',
        '`violations` must be a list of violation ids.',
      ),
    ]) {
      test('throws for $name', () async {
        File(path).writeAsStringSync(content);
        await expectLater(
          BaselineFile(path).read(),
          baselineError(
            startsWith('Baseline file `$path` is malformed: $detail'),
          ),
        );
      });
    }
  });
}
