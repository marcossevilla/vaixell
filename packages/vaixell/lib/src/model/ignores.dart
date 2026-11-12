part of 'model.dart';

/// The rules that ignore comments in a Dart file turn off.
///
/// `// ignore: <id>, <id>` turns rules off on one line: the next line when
/// the comment is alone on its line, or its own line when it follows code.
/// `// ignore_for_file: <id>, <id>` turns them off on every line of the
/// file, wherever it is. Ids that aren't vaixell's, such as analyzer codes
/// in the same comment, are kept too, since they can't match a vaixell rule.
/// Only `//` comments count: doc comments, block comments and strings don't.
final class Ignores {
  /// The ignores of [file], which must come from [DartFile.parse].
  factory of(DartFile file) => (file as _AstDartFile).ignores;

  new _(ParseStringResult result) {
    for (final comment in _comments(result.unit.beginToken)) {
      _forFile.addAll(_ids(_ignoreForFile, comment.lexeme));
      final ids = _ids(_ignore, comment.lexeme);
      if (ids.isEmpty) continue;
      final location = result.lineInfo.getLocation(comment.offset);
      final before = result.content.substring(
        comment.offset - location.columnNumber + 1,
        comment.offset,
      );
      final line = location.lineNumber + (before.trim().isEmpty ? 1 : 0);
      _byLine.putIfAbsent(line, () => {}).addAll(ids);
    }
  }

  static final RegExp _ignore = RegExp(r'^//\s*ignore:(.*)$');

  static final RegExp _ignoreForFile = RegExp(r'^//\s*ignore_for_file:(.*)$');

  final Map<int, Set<String>> _byLine = {};

  final Set<String> _forFile = {};

  /// Whether a comment turns off the rule [rule] at the 1-based [line].
  bool ignores(String rule, int line) =>
      _forFile.contains(rule) || (_byLine[line]?.contains(rule) ?? false);

  /// The `//` comments before each token, in source order.
  Iterable<Token> _comments(Token first) sync* {
    for (Token? token = first; token != null; token = token.next) {
      for (Token? c = token.precedingComments; c != null; c = c.next) {
        if (c.type == TokenType.SINGLE_LINE_COMMENT) yield c;
      }
      if (token.isEof) return;
    }
  }

  /// The comma-separated ids after [pattern] in [comment], if it matches.
  Set<String> _ids(RegExp pattern, String comment) {
    final ids = pattern.firstMatch(comment)?[1];
    if (ids == null) return const {};
    return {
      for (final id in ids.split(','))
        if (id.trim() case final trimmed when trimmed.isNotEmpty) trimmed,
    };
  }
}
