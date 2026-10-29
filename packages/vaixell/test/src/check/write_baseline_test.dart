import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

import '../../helpers/memory_source_tree.dart';

void main() {
  group(WriteBaseline, () {
    setUp(
      () => d.dir('lib', [
        d.file('a.dart', 'void foo() {}\nvoid bar() {}\n'),
      ]).create(),
    );

    test('writes the violation ids and returns the baseline', () async {
      final baseline = await WriteBaseline(root: d.sandbox)('baseline.json');
      expect(
        baseline.ids,
        equals({
          'top-level-function:lib/a.dart:bar',
          'top-level-function:lib/a.dart:foo',
        }),
      );
      await d
          .file(
            'baseline.json',
            '{\n'
                '  "schemaVersion": 1,\n'
                '  "violations": [\n'
                '    "top-level-function:lib/a.dart:bar",\n'
                '    "top-level-function:lib/a.dart:foo"\n'
                '  ]\n'
                '}\n',
          )
          .validate();
    });

    test('checks only the given paths', () async {
      await d.dir('packages/b', [
        d.file('pubspec.yaml', 'name: b\n'),
        d.dir('lib', [d.file('b.dart', 'void b() {}\n')]),
      ]).create();
      final baseline = await WriteBaseline(root: d.sandbox)(
        'baseline.json',
        paths: ['packages/b'],
      );
      expect(
        baseline.ids,
        equals({'top-level-function:packages/b/lib/b.dart:b'}),
      );
    });

    test('reads the files from the given tree', () async {
      final tree = MemorySourceTree({'lib/c.dart': 'void c() {}\n'});
      final baseline = await WriteBaseline(root: d.sandbox, tree: tree)(
        'baseline.json',
      );
      expect(baseline.ids, equals({'top-level-function:lib/c.dart:c'}));
      expect(
        (await BaselineFile(d.path('baseline.json')).read()).ids,
        equals(baseline.ids),
      );
    });

    test('throws a ConfigException on an invalid config', () async {
      await d.file('analysis_options.yaml', 'vaixell:\n  rulez: {}\n').create();
      await expectLater(
        WriteBaseline(root: d.sandbox)('baseline.json'),
        throwsA(isA<ConfigException>()),
      );
      await d.nothing('baseline.json').validate();
    });
  });
}
