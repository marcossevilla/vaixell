import 'package:test/test.dart';
import 'package:vaixell/src/check/package_resolver.dart';
import 'package:vaixell/src/engine/package.dart';
import 'package:vaixell/vaixell.dart';

import '../../helpers/memory_source_tree.dart';
import '../../helpers/severities.dart';

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

    Future<List<Package>> resolve(List<String> paths) => PackageResolver(
      root: '/repo',
      tree: tree,
      rules: Recommended.rules,
    )(paths);

    test('discovers the packages when there are no paths', () async {
      final packages = await resolve([]);
      expect(packages.map((p) => p.path), equals(['', 'packages/a']));
    });

    test('resolves each package with its nearest config', () async {
      final [root, a] = await resolve([]);
      expect(severitiesOf(root.config), isNot(contains('top-level-variable')));
      expect(severitiesOf(root.config), contains('top-level-function'));
      expect(severitiesOf(a.config), isNot(contains('top-level-function')));
      expect(severitiesOf(a.config), contains('top-level-variable'));
    });

    test('names each package after its pubspec', () async {
      expect((await resolve([])).map((p) => p.name), ['w', 'a']);
      expect((await resolve(['packages/a'])).map((p) => p.name), ['a']);
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

    test('throws a $ConfigException for an invalid workspace', () async {
      tree.files['pubspec.yaml'] = 'workspace:\n  - packages/c\n';
      await expectLater(resolve([]), throwsA(isA<ConfigException>()));
    });

    test('throws an ArgumentError for a repeated rule id', () {
      expect(
        () => PackageResolver(
          root: '/repo',
          tree: tree,
          rules: [...Recommended.rules, Recommended.rules.first],
        ),
        throwsArgumentError,
      );
    });

    test('skips discovery when paths are given', () async {
      // Discovery would fail on this workspace.
      tree.files['pubspec.yaml'] = 'workspace:\n  - packages/c\n';
      final packages = await resolve(['packages/a']);
      expect(packages.map((p) => p.path), equals(['packages/a']));
    });

    for (final path in ['..', '../repo2', 'packages/../../x', '/elsewhere']) {
      test('throws an ArgumentError for `$path` outside the root', () async {
        await expectLater(resolve([path]), throwsArgumentError);
      });
    }

    test('accepts the root given as an absolute path', () async {
      final packages = await resolve(['/repo/packages/a']);
      expect(packages.map((p) => p.path), equals(['packages/a']));
    });
  });
}
