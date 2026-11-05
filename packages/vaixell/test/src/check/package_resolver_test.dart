import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:vaixell/vaixell.dart';

import '../../helpers/memory_source_tree.dart';
import '../../helpers/severities.dart';

class _MockPackageDiscovery extends Mock implements PackageDiscovery;

class _MockConfigResolver extends Mock implements ConfigResolver;

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
        PackageResolver.fromTree(
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

    test('uses the given discovery and config resolver', () async {
      final discovery = _MockPackageDiscovery();
      final configResolver = _MockConfigResolver();
      final a = Config.recommended(Recommended.rules);
      const b = Config(rules: []);
      when(discovery.discover).thenAnswer((_) async => ['x', 'y']);
      when(() => configResolver.forPackages(['x', 'y']))
          .thenAnswer((_) async => [a, b]);

      final packages = await PackageResolver(
        root: '/repo',
        discovery: discovery,
        configResolver: configResolver,
      )([]);

      expect(packages.map((p) => (p.path, p.config)), [('x', a), ('y', b)]);
    });

    test('skips discovery when paths are given', () async {
      final discovery = _MockPackageDiscovery();
      final configResolver = _MockConfigResolver();
      when(() => configResolver.forPackages(['x']))
          .thenAnswer((_) async => [Config.recommended(Recommended.rules)]);

      await PackageResolver(
        root: '/repo',
        discovery: discovery,
        configResolver: configResolver,
      )(['x']);

      verifyNever(discovery.discover);
    });
  });
}
