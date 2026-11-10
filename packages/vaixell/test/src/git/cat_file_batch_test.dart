import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:vaixell/src/git/cat_file_batch.dart';
import 'package:vaixell/src/git/git_runner.dart';

import '../../helpers/git_repo.dart';

void main() {
  group(CatFileBatch, () {
    Future<CatFileBatch> start() async {
      final batch = CatFileBatch(
        await GitRunner(d.sandbox).start(['cat-file', '--batch']),
      );
      addTearDown(batch.close);
      return batch;
    }

    test('reads blobs and skips trees and missing objects in order', () async {
      await gitInit(d.sandbox);
      await d.dir('lib', [
        d.file('a.dart', 'a\n'),
        d.file('b.dart', ''),
      ]).create();
      await gitCommitAll(d.sandbox);

      final batch = await start();
      final results = await Future.wait([
        batch.blob('HEAD:./lib/a.dart'),
        batch.blob('HEAD:./lib/missing.dart'),
        batch.blob('HEAD:./lib'),
        batch.blob('HEAD:./lib/b.dart'),
      ]);
      expect(utf8.decode(results[0]!), equals('a\n'));
      expect(results[1], isNull);
      expect(results[2], isNull);
      expect(results[3], isEmpty);
    });

    test('reads specs with spaces, missing or not', () async {
      await gitInit(d.sandbox);
      await d.dir('my lib', [d.file('a b.dart', 'a')]).create();
      await gitCommitAll(d.sandbox);

      final batch = await start();
      expect(utf8.decode((await batch.blob('HEAD:./my lib/a b.dart'))!), 'a');
      expect(await batch.blob('HEAD:./my lib/c d.dart'), isNull);
      expect(await batch.blob('HEAD:./my lib/a b.dart'), isNotNull);
    });

    test('returns null for an ambiguous spec with spaces', () async {
      final stdout = StreamController<List<int>>();
      final stdin = StreamController<List<int>>();
      addTearDown(stdout.close);
      addTearDown(stdin.close);
      stdin.stream.listen((_) => stdout.add(utf8.encode('a b c ambiguous\n')));
      final process = _MockProcess();
      when(() => process.stdout).thenAnswer((_) => stdout.stream);
      when(() => process.stderr).thenAnswer((_) => const Stream.empty());
      when(() => process.stdin).thenReturn(IOSink(stdin));

      expect(await CatFileBatch(process).blob('a b c'), isNull);
    });

    test('reads blobs larger than one stdout chunk', () async {
      await gitInit(d.sandbox);
      final content = 'x' * (1024 * 1024);
      await d.file('big.txt', content).create();
      await gitCommitAll(d.sandbox);

      final batch = await start();
      final big = await batch.blob('HEAD:./big.txt');
      expect(big, hasLength(content.length));
      expect(await batch.blob('HEAD:./missing'), isNull);
    });

    test('waits for a blob that arrives after its header', () async {
      final stdout = StreamController<List<int>>();
      final stdin = StreamController<List<int>>();
      addTearDown(stdout.close);
      addTearDown(stdin.close);
      stdin.stream.listen((_) => stdout.add(utf8.encode('abc blob 3\n')));
      final process = _MockProcess();
      when(() => process.stdout).thenAnswer((_) => stdout.stream);
      when(() => process.stderr).thenAnswer((_) => const Stream.empty());
      when(() => process.stdin).thenReturn(IOSink(stdin));

      final batch = CatFileBatch(process);
      final result = batch.blob('HEAD:./a');
      await pumpEventQueue();
      stdout.add(utf8.encode('xyz\n'));

      expect(utf8.decode((await result)!), equals('xyz'));
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
      await expectLater(batch.blob('HEAD:./a'), exited);
    });

    test('throws when the process exits without answering', () async {
      final process = await Process.start('sh', ['-c', 'read line']);
      final batch = CatFileBatch(process);
      await expectLater(batch.blob('HEAD:./a'), exited);
      await expectLater(batch.blob('HEAD:./b'), exited);
    });
  });
}

class _MockProcess extends Mock implements Process;
