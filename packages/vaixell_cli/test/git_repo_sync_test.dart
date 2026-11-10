import 'dart:io';

import 'package:test/test.dart';

/// Returns the lines of the helper at [path] after its two-line header,
/// which names the other copy.
List<String> _body(String path) =>
    File(path).readAsLinesSync().skip(2).toList();

void main() {
  test('helpers/git_repo.dart matches the copy in vaixell', () {
    // Tests run from the package root.
    expect(
      _body('test/helpers/git_repo.dart'),
      equals(_body('../vaixell/test/helpers/git_repo.dart')),
    );
  });
}
