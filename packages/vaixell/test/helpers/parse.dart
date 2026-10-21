import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Parses [content] as the file at [path].
ParsedFile parse(String content, {String path = 'lib/a.dart'}) => ParsedFile(
  path: path,
  result: parseString(content: content, path: path, throwIfDiagnostics: false),
);
