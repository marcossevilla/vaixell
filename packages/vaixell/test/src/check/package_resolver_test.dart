import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';

import '../../helpers/memory_source_tree.dart';

void main() {
  group(PackageResolver, () {
    late MemorySourceTree tree;

    setUp(() {
      tree = MemorySourceTree({
        'pubspec.yaml': 'name: w\nworkspace:\n  - packages/a\n',
        'analysis_options.yaml':
            'vaixell:\n  rules:\n    top-level-variable: off\n',
        'packages/a/pubspec.yaml': 'name: a\n',
        'packages/a/analysis_options.yaml':
            'vaixell:\n  rules:\n    top-level-function: off\n',
      });
    });

    Future<List<Package>> resolve(List<String> paths) =>
        PackageResolver(root: '/repo', tree: tree)(paths);

    test('discovers the packages when there are no paths', () async {
      final packages = await resolve([]);
      expect(packages.map((p) => p.path), equals(['', 'packages/a']));
    });

    test('resolves each package with its nearest config', () async {
      final [root, a] = await resolve([]);
      expect(root.config.severities, isNot(contains('top-level-variable')));
      expect(root.config.severities, contains('top-level-function'));
      expect(a.config.severities, isNot(contains('top-level-function')));
      expect(a.config.severities, contains('top-level-variable'));
    });

    test('normalizes and dedupes the given paths', () async {
      final packages = await resolve([
        'packages/a',
        'packages/a/',
        './packages/a',
        '.',
      ]);
      expect(packages.map((p) => p.path), equals(['packages/a', '']));
    });

    test('throws a ConfigException for an invalid workspace', () async {
      tree.files['pubspec.yaml'] = 'workspace:\n  - packages/c\n';
      await expectLater(resolve([]), throwsA(isA<ConfigException>()));
    });
  });
}
