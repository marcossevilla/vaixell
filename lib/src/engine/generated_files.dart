/// Recognizes files produced by code generators.
class GeneratedFiles {
  /// Creates a matcher for generated files.
  const GeneratedFiles();

  static const List<String> _suffixes = [
    '.g.dart',
    '.freezed.dart',
    '.gr.dart',
    '.gen.dart',
    '.mocks.dart',
    '.pb.dart',
    '.pbenum.dart',
    '.pbgrpc.dart',
    '.pbjson.dart',
    '.pbserver.dart',
  ];

  /// Whether [path] looks like a generated file.
  bool matches(String path) => _suffixes.any(path.endsWith);
}
