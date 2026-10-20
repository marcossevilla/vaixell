import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:theseus_cli/theseus_cli.dart';

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

    test('returns no files for a missing directory', () async {
      expect(await tree.listFiles('missing'), isEmpty);
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
