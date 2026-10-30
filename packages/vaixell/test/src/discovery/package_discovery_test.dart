import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

import '../../helpers/git_repo.dart';
import '../../helpers/memory_source_tree.dart';

Future<List<String>> _discover(Map<String, String> files) =>
    PackageDiscovery(MemorySourceTree(files)).discover();

void main() {
  group(PackageDiscovery, () {
    test('a workspace finds the root and its members', () async {
      expect(
        await _discover({
          'pubspec.yaml': 'name: w\nworkspace:\n  - packages/b\n  - apps/a/\n',
          'packages/b/pubspec.yaml': 'name: b\n',
          'apps/a/pubspec.yaml': 'name: a\n',
          'packages/unlisted/pubspec.yaml': 'name: u\n',
          'example/pubspec.yaml': 'name: e\n',
        }),
        equals(['', 'apps/a', 'packages/b']),
      );
    });

    group('a workspace with glob members', () {
      test('finds the directories with a pubspec.yaml', () async {
        expect(
          await _discover({
            'pubspec.yaml': 'name: w\nworkspace:\n  - packages/*\n',
            'packages/b/pubspec.yaml': 'name: b\n',
            'packages/a/pubspec.yaml': 'name: a\n',
            'packages/a/example/pubspec.yaml': 'name: e\n',
            'packages/notes/README.md': '',
            'packages/pubspec.yaml': 'name: p\n',
          }),
          equals(['', 'packages/a', 'packages/b']),
        );
      });

      test('supports ** and braces', () async {
        final files = {
          'packages/a/pubspec.yaml': 'name: a\n',
          'packages/deep/x/pubspec.yaml': 'name: x\n',
          'apps/c/pubspec.yaml': 'name: c\n',
          'apps/d/pubspec.yaml': 'name: d\n',
        };
        expect(
          await _discover({
            'pubspec.yaml': 'name: w\nworkspace:\n  - packages/**\n',
            ...files,
          }),
          equals(['', 'packages/a', 'packages/deep/x']),
        );
        expect(
          await _discover({
            'pubspec.yaml': 'name: w\nworkspace:\n  - "apps/{c,e}"\n',
            ...files,
          }),
          equals(['', 'apps/c']),
        );
      });

      test('matches directories at the root but not the root', () async {
        expect(
          await _discover({
            'pubspec.yaml': 'name: w\nworkspace:\n  - "*"\n',
            'a/pubspec.yaml': 'name: a\n',
            'b/README.md': '',
          }),
          equals(['', 'a']),
        );
      });

      test('lists a package matched by several members once', () async {
        expect(
          await _discover({
            'pubspec.yaml':
                'name: w\nworkspace:\n  - packages/*\n  - packages/a\n',
            'packages/a/pubspec.yaml': 'name: a\n',
          }),
          equals(['', 'packages/a']),
        );
      });
    });

    test('a single package finds only the root', () async {
      expect(
        await _discover({
          'pubspec.yaml': 'name: a\n',
          'lib/a.dart': '',
          'example/pubspec.yaml': 'name: e\n',
        }),
        equals(['']),
      );
    });

    test('a root package also finds packages/* and pkgs/*', () async {
      expect(
        await _discover({
          'pubspec.yaml': 'name: app\n',
          'packages/ui/pubspec.yaml': 'name: ui\n',
          'packages/notes/README.md': '',
          'pkgs/api/pubspec.yaml': 'name: api\n',
          'example/pubspec.yaml': 'name: e\n',
        }),
        equals(['', 'packages/ui', 'pkgs/api']),
      );
    });

    test('a monorepo without a root pubspec finds its packages', () async {
      expect(
        await _discover({
          'packages/b/pubspec.yaml': 'name: b\n',
          'pkgs/c/pubspec.yaml': 'name: c\n',
          'a/pubspec.yaml': 'name: a\n',
          'docs/README.md': '',
        }),
        equals(['a', 'packages/b', 'pkgs/c']),
      );
    });

    test('falls back to the root when there are no packages', () async {
      expect(await _discover({'lib/a.dart': ''}), equals(['']));
      expect(await _discover({}), equals(['']));
    });

    test('a non-map pubspec has no workspace', () async {
      expect(await _discover({'pubspec.yaml': '- a\n'}), equals(['']));
    });

    group('invalid workspace', () {
      final cases = <String, (String, String)>{
        'invalid YAML': ('name: w\nworkspace: [\n', 'pubspec.yaml:3:1: '),
        'a non-list workspace': (
          'workspace: packages/a\n',
          'pubspec.yaml:1:12: `workspace` must be a list of package paths.',
        ),
        'a non-string member': (
          'workspace:\n  - 1\n',
          'pubspec.yaml:2:5: `workspace` must be a list of package paths.',
        ),
        'a member outside the workspace': (
          'workspace:\n  - ../other\n',
          'pubspec.yaml:2:5: Workspace member `../other` must be a '
              'directory inside the workspace.',
        ),
        'the root as a member': (
          'workspace:\n  - ./\n',
          'pubspec.yaml:2:5: Workspace member `./` must be a directory '
              'inside the workspace.',
        ),
        'an absolute member': (
          'workspace:\n  - /abs\n',
          'pubspec.yaml:2:5: Workspace member `/abs` must be a directory',
        ),
        'a member without a pubspec': (
          'workspace:\n  - packages/missing\n',
          'pubspec.yaml:2:5: Workspace member `packages/missing` has no '
              'pubspec.yaml.',
        ),
        'a glob member that matches nothing': (
          'workspace:\n  - packages/*\n',
          'pubspec.yaml:2:5: Workspace member `packages/*` matches no '
              'directory with a pubspec.yaml.',
        ),
        'an invalid glob member': (
          'workspace:\n  - packages/[a\n',
          'pubspec.yaml:2:5: Workspace member `packages/[a` is not a valid '
              'glob: ',
        ),
      };
      for (final MapEntry(key: name, value: (pubspec, message))
          in cases.entries) {
        test(name, () async {
          await expectLater(
            _discover({'pubspec.yaml': pubspec}),
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

    test('works the same on a git tree', () async {
      await gitInit(d.sandbox);
      await d
          .file('pubspec.yaml', 'name: w\nworkspace:\n  - packages/*\n')
          .create();
      await d.dir('packages/a', [d.file('pubspec.yaml', 'name: a\n')]).create();
      await gitCommitAll(d.sandbox);
      final commit = (await git(d.sandbox, ['rev-parse', 'HEAD'])).trim();
      // Uncommitted changes aren't part of the commit.
      await d.dir('packages/b', [d.file('pubspec.yaml', 'name: b\n')]).create();

      final tree = GitSourceTree(git: GitRunner(d.sandbox), commit: commit);
      addTearDown(tree.close);
      expect(
        await PackageDiscovery(tree).discover(),
        equals(['', 'packages/a']),
      );
    });
  });
}
