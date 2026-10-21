import 'package:theseus_cli/theseus_cli.dart';

/// A [SourceTree] backed by a map of path to contents.
class MemorySourceTree implements SourceTree {
  new(this.files);

  final Map<String, String> files;

  @override
  Future<List<String>> listFiles(String directory) async => [
    for (final path in files.keys)
      if (path.startsWith('$directory/')) path,
  ]..sort();

  /// The paths passed to [read], in order.
  final List<String> reads = [];

  @override
  Future<List<String>> listDirectories(String directory) async {
    final prefix = directory.isEmpty ? '' : '$directory/';
    return {
      for (final path in files.keys)
        if (path.startsWith(prefix) &&
            path.substring(prefix.length).contains('/'))
          '$prefix${path.substring(prefix.length).split('/').first}',
    }.toList()..sort();
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<String> read(String path) async {
    reads.add(path);
    return files[path]!;
  }
}
