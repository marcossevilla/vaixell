import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

import '../helpers/git_repo.dart';

void main() {
  group(GitSourceTree, () {
    late String commit;

    setUp(() async {
      await gitInit(d.sandbox);
      await d.dir('pkg', [
        d.file('analysis_options.yaml', 'vaixell:\n'),
        d.dir('lib', [
          d.file('b.dart', 'b'),
          d.dir('src', [d.file('a.dart', 'a')]),
        ]),
      ]).create();
      await gitCommitAll(d.sandbox);
      commit = (await git(d.sandbox, ['rev-parse', 'HEAD'])).trim();
      await d.dir('pkg/lib', [d.file('b.dart', 'changed')]).create();
    });

    GitSourceTree treeIn(String directory) =>
        GitSourceTree(git: GitRunner(directory), commit: commit);

    test('reads the commit, not the working tree', () async {
      final tree = treeIn(d.path('pkg'));
      addTearDown(tree.close);
      expect(await tree.read('lib/b.dart'), equals('b'));
    });

    test('lists files relative to the working directory', () async {
      final tree = treeIn(d.path('pkg'));
      expect(
        await tree.listFiles('lib'),
        equals(['lib/b.dart', 'lib/src/a.dart']),
      );
      expect(await tree.listFiles('missing'), isEmpty);
    });

    test('lists files from the repository root', () async {
      final tree = treeIn(d.sandbox);
      expect(
        await tree.listFiles(p.join('pkg', 'lib', 'src')),
        equals(['pkg/lib/src/a.dart']),
      );
    });

    test('lists immediate subdirectories at the commit', () async {
      await d.dir('pkg/untracked/dir').create();
      final tree = treeIn(d.path('pkg'));
      expect(await tree.listDirectories(''), equals(['lib']));
      expect(await tree.listDirectories('lib'), equals(['lib/src']));
      expect(await tree.listDirectories('missing'), isEmpty);
      expect(await treeIn(d.sandbox).listDirectories(''), equals(['pkg']));
    });

    test('checks whether files exist', () async {
      final tree = treeIn(d.path('pkg'));
      addTearDown(tree.close);
      expect(await tree.exists('analysis_options.yaml'), isTrue);
      expect(await tree.exists('lib'), isFalse);
      expect(await tree.exists('missing.yaml'), isFalse);
    });

    test('throws when reading a missing file', () async {
      final tree = treeIn(d.path('pkg'));
      addTearDown(tree.close);
      await expectLater(
        tree.read('lib/missing.dart'),
        throwsA(
          isA<GitException>().having(
            (e) => e.message,
            'message',
            '`lib/missing.dart` is not a file at $commit.',
          ),
        ),
      );
    });

    test('close works before any file is read', () async {
      await treeIn(d.path('pkg')).close();
    });
  });
}
