import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:theseus_cli/src/git/cat_file_batch.dart';
import 'package:theseus_cli/theseus_cli.dart';

import '../helpers/git_repo.dart';

void main() {
  group(CatFileBatch, () {
    test('reads blobs, trees and missing objects in order', () async {
      await gitInit(d.sandbox);
      await d.dir('lib', [
        d.file('a.dart', 'a\n'),
        d.file('b.dart', ''),
      ]).create();
      await gitCommitAll(d.sandbox);

      final batch = CatFileBatch(
        await GitRunner(d.sandbox).start(['cat-file', '--batch']),
      );
      addTearDown(batch.close);
      final results = await Future.wait([
        batch.lookup('HEAD:./lib/a.dart'),
        batch.lookup('HEAD:./lib/missing.dart'),
        batch.lookup('HEAD:./lib'),
        batch.lookup('HEAD:./lib/b.dart'),
      ]);
      expect(results[0]!.type, equals('blob'));
      expect(utf8.decode(results[0]!.bytes), equals('a\n'));
      expect(results[1], isNull);
      expect(results[2]!.type, equals('tree'));
      expect(results[3]!.bytes, isEmpty);
    });

    test('reads blobs larger than one stdout chunk', () async {
      await gitInit(d.sandbox);
      final content = 'x' * (1024 * 1024);
      await d.file('big.txt', content).create();
      await gitCommitAll(d.sandbox);

      final batch = CatFileBatch(
        await GitRunner(d.sandbox).start(['cat-file', '--batch']),
      );
      addTearDown(batch.close);
      final big = await batch.lookup('HEAD:./big.txt');
      expect(big!.bytes, hasLength(content.length));
      expect(await batch.lookup('HEAD:./missing'), isNull);
    });

    final exited = throwsA(
      isA<GitException>().having(
        (e) => e.message,
        'message',
        '`git cat-file --batch` exited unexpectedly.',
      ),
    );

    test('throws when the process has already exited', () async {
      final process = await Process.start('sh', ['-c', 'exit 0']);
      await process.exitCode;
      final batch = CatFileBatch(process);
      await expectLater(batch.lookup('HEAD:./a'), exited);
    });

    test('throws when the process exits without answering', () async {
      final process = await Process.start('sh', ['-c', 'read line']);
      final batch = CatFileBatch(process);
      await expectLater(batch.lookup('HEAD:./a'), exited);
      await expectLater(batch.lookup('HEAD:./b'), exited);
    });
  });
}
