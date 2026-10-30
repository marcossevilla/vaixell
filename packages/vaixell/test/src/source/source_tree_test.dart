import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/vaixell.dart';

void main() {
  group(FileSystemSourceTree, () {
    late FileSystemSourceTree tree;

    setUp(() async {
      await d.dir('lib', [
        d.file('b.dart', 'b'),
        d.dir('src', [d.file('a.dart', 'a')]),
      ]).create();
      await d.file('pubspec.yaml', 'name: x').create();
      tree = FileSystemSourceTree(Directory(d.sandbox));
    });

    test('lists files under a directory as sorted POSIX paths', () async {
      expect(
        await tree.listFiles('lib'),
        equals(['lib/b.dart', 'lib/src/a.dart']),
      );
    });

    test('lists files under the root', () async {
      expect(
        await tree.listFiles(''),
        equals(['lib/b.dart', 'lib/src/a.dart', 'pubspec.yaml']),
      );
    });

    test('returns no files for a missing directory', () async {
      expect(await tree.listFiles('missing'), isEmpty);
    });

    test('lists immediate subdirectories as sorted POSIX paths', () async {
      await d.dir('lib/src/deep/er').create();
      await d.dir('tool').create();
      expect(await tree.listDirectories(''), equals(['lib', 'tool']));
      expect(await tree.listDirectories('lib'), equals(['lib/src']));
      expect(await tree.listDirectories('lib/src/a.dart'), isEmpty);
      expect(await tree.listDirectories('missing'), isEmpty);
    });

    test('checks whether files exist', () async {
      expect(await tree.exists('pubspec.yaml'), isTrue);
      expect(await tree.exists('lib/src/a.dart'), isTrue);
      expect(await tree.exists('lib/src'), isFalse);
      expect(await tree.exists('missing.yaml'), isFalse);
    });

    test('reads files and tolerates malformed UTF-8', () async {
      expect(await tree.read('lib/src/a.dart'), equals('a'));
      await File('${d.sandbox}/lib/bad.dart').writeAsBytes([0x61, 0xff]);
      expect(await tree.read('lib/bad.dart'), equals('a\uFFFD'));
    });
  });
}
