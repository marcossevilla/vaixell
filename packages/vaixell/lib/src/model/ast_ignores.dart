part of 'model.dart';

/// `// ignore: <ids>` or `// ignore_for_file: <ids>`, with the
/// `_for_file` suffix in group 1 and the text after the colon in group 2.
final RegExp _ignoreComment = RegExp(r'^//\s*ignore(_for_file)?:(.*)$');

/// The comma-separated ids at the start of a comment's text, without
/// anything that follows them.
final RegExp _ignoredIds = RegExp(r'^\s*[\w-]+(?:\s*,\s*[\w-]+)*');

/// The ignores that the `//` comments of [result] declare.
Ignores _ignoresOf(ParseStringResult result) {
  final byLine = <int, Set<String>>{};
  final forFile = <String>{};
  for (final comment in _comments(result.unit.beginToken)) {
    final match = _ignoreComment.firstMatch(comment.lexeme);
    if (match == null) continue;
    final ids = _ids(match[2]!);
    if (match[1] != null) {
      forFile.addAll(ids);
      continue;
    }
    if (ids.isEmpty) continue;
    final line = result.lineInfo.getLocation(comment.offset).lineNumber;
    final lineStart = result.lineInfo.getOffsetOfLine(line - 1);
    final alone = result.content
        .substring(lineStart, comment.offset)
        .trim()
        .isEmpty;
    byLine.putIfAbsent(alone ? line + 1 : line, () => {}).addAll(ids);
  }
  return Ignores._(byLine, forFile);
}

/// The `//` comments before each token, in source order.
Iterable<Token> _comments(Token first) sync* {
  for (Token? token = first; token != null; token = token.next) {
    for (Token? c = token.precedingComments; c != null; c = c.next) {
      if (c.type == TokenType.SINGLE_LINE_COMMENT) yield c;
    }
    if (token.isEof) return;
  }
}

/// The ids at the start of [text], the part of a comment after its colon.
Set<String> _ids(String text) => {
  for (final id in _ignoredIds.firstMatch(text)?[0]?.split(',') ?? <String>[])
    id.trim(),
};
