import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vaixell/src/git/git_runner.dart';

/// A git object read by [CatFileBatch].
class const GitObject({
  /// The object type, for example `blob` or `tree`.
  required final String type,

  /// The raw contents of the object.
  required final List<int> bytes,
}) {
  /// Creates an object of [type] with [bytes] as its contents.
  this;
}

/// Reads git objects through one long-running `git cat-file --batch`
/// process.
class CatFileBatch(final Process _process) {
  /// Creates a reader that talks to a started `git cat-file --batch`
  /// process.
  this {
    _process.stdout.listen(_onData, onDone: _onDone);
  }

  static const GitException _exited = GitException(
    '`git cat-file --batch` exited unexpectedly.',
  );

  final List<int> _buffer = [];
  Completer<void>? _waiting;
  bool _done = false;
  Future<void> _queue = Future.value();

  /// Returns the object named by [spec], such as `<commit>:./lib/a.dart`,
  /// or `null` if it doesn't exist.
  ///
  /// Lookups are answered in the order they're made.
  Future<GitObject?> lookup(String spec) {
    final result = _queue.then((_) => _lookup(spec));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Stops the git process.
  Future<void> close() async {
    await _process.stdin.close();
    await _process.exitCode;
  }

  Future<GitObject?> _lookup(String spec) async {
    try {
      _process.stdin.add(utf8.encode('$spec\n'));
      await _process.stdin.flush();
    } on IOException {
      throw _exited;
    }
    final header = utf8.decode(await _readLine()).split(' ');
    if (header.length != 3) return null;
    final size = int.parse(header[2]);
    final bytes = await _take(size + 1);
    return GitObject(type: header[1], bytes: bytes.sublist(0, size));
  }

  Future<List<int>> _readLine() async {
    var end = _buffer.indexOf(0x0a);
    while (end == -1) {
      await _more();
      end = _buffer.indexOf(0x0a);
    }
    final line = await _take(end + 1);
    return line.sublist(0, end);
  }

  Future<List<int>> _take(int count) async {
    while (_buffer.length < count) {
      await _more();
    }
    final bytes = _buffer.sublist(0, count);
    _buffer.removeRange(0, count);
    return bytes;
  }

  Future<void> _more() {
    if (_done) throw _exited;
    return (_waiting = Completer<void>()).future;
  }

  void _onData(List<int> data) {
    _buffer.addAll(data);
    _waiting?.complete();
    _waiting = null;
  }

  void _onDone() {
    _done = true;
    _waiting?.complete();
    _waiting = null;
  }
}
