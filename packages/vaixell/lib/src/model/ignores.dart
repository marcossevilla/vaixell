part of 'model.dart';

/// The rules that ignore comments in a Dart file turn off.
///
/// `// ignore: <id>, <id>` turns rules off on one line: the next line when
/// the comment is alone on its line, or its own line when it follows code.
/// `// ignore_for_file: <id>, <id>` turns them off on every line of the
/// file, wherever it is. Ids that aren't vaixell's, such as analyzer codes
/// in the same comment, are kept too, since they can't match a vaixell rule.
/// Text after the ids, such as a reason, is skipped.
/// Only `//` comments count: doc comments, block comments and strings don't.
///
/// The engine applies them; rules never read them.
final class Ignores {
  /// The ignores of [file]. A [DartFile] that doesn't come from
  /// [DartFile.parse] has none.
  factory of(DartFile file) => switch (file) {
    _AstDartFile(:final ignores) => ignores,
    _ => _none,
  };

  const new _(this._byLine, this._forFile);

  static const Ignores _none = Ignores._({}, {});

  final Map<int, Set<String>> _byLine;

  final Set<String> _forFile;

  /// Whether a comment turns off the rule [rule] on the 1-based [line].
  bool turnsOff(String rule, {required int line}) =>
      turnsOffFile(rule) || (_byLine[line]?.contains(rule) ?? false);

  /// Whether an `ignore_for_file` comment turns off the rule [rule] on
  /// every line.
  bool turnsOffFile(String rule) => _forFile.contains(rule);
}
