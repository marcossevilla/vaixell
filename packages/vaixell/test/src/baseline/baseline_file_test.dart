import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/src/baseline/baseline_file.dart';
import 'package:vaixell/vaixell.dart';

void main() {
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

    test('throws when the directory is missing on write', () async {
      final missing = d.path('missing/baseline.json');
      await expectLater(
        BaselineFile(missing).write(Baseline(['a'])),
        baselineError(startsWith('Could not write baseline file `$missing`: ')),
      );
    });

    test('throws when the path is a directory on read', () async {
      await d.dir('baseline.json').create();
      await expectLater(
        BaselineFile(path).read(),
        baselineError(startsWith('Could not read baseline file `$path`: ')),
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
