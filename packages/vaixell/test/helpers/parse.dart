import 'package:vaixell/src/model/model.dart';

/// Parses [content] as the file at [path].
DartFile parse(String content, {String path = 'lib/a.dart'}) =>
    const DartFileParser().parse(path: path, content: content);
