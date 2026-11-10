import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vaixell/src/git/git_runner.dart';

/// Reads git objects through one long-running `git cat-file --batch`
/// process.
class CatFileBatch(final Process _process) {
  /// Creates a reader that talks to a started `git cat-file --batch`
  /// process.
  ///
  /// Its stderr is drained, since `cat-file` reports missing objects on
  /// stdout.
  this {
    _stdout = _process.stdout.listen(_onData, onDone: _onDone);
    unawaited(_process.stderr.drain<void>());
  }

  static const GitException _exited = GitException(
    '`git cat-file --batch` exited unexpectedly.',
  );

  late final StreamSubscription<List<int>> _stdout;
  final List<int> _buffer = [];
  Completer<void>? _waiting;
  bool _done = false;
  Future<void> _queue = Future.value();

  /// Returns the contents of the blob named by [spec], such as
  /// `<commit>:./lib/a.dart`, or `null` if it doesn't exist or isn't a blob.
  ///
  /// Lookups are answered in the order they're made.
  Future<List<int>?> blob(String spec) {
    final result = _queue.then((_) => _lookup(spec));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Stops the git process.
  Future<void> close() async {
    await _process.stdin.close();
    await _process.exitCode;
    await _stdout.cancel();
  }

  Future<List<int>?> _lookup(String spec) async {
    // A failed write means the process exited, which closes stdout too, so
    // the read below reports it.
    _process.stdin.add(utf8.encode('$spec\n'));
    await _process.stdin.flush().then((_) {}, onError: (_) {});
    // `<oid> <type> <size>`, or `<spec> missing` and `<spec> ambiguous`,
    // where the spec can hold spaces.
    final header = utf8.decode(await _readLine()).split(' ');
    if (header.last case 'missing' || 'ambiguous') return null;
    final [..., type, sizeText] = header;
    final size = int.parse(sizeText);
    final bytes = await _take(size + 1);
    return type == 'blob' ? bytes.sublist(0, size) : null;
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
