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

  @override
  Future<String> read(String path) async => files[path]!;
}
