import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The `lib/src` layers each layer may import, besides itself.
///
/// A layer is a directory under `lib/src`, or a file directly in it.
const _allowedImports = <String, Set<String>>{
  'violation': {},
  'rules': {'violation'},
  'config': {'rules', 'source', 'violation'},
  'source': {'git'},
  'engine': {'config', 'rules', 'source', 'violation'},
  'report': {'engine', 'violation'},
  'baseline': {},
  'discovery': {'config', 'source'},
  'git': {},
  'check': {
    'baseline',
    'config',
    'discovery',
    'engine',
    'git',
    'report',
    'source',
    'violation',
  },
};

const _src = 'lib/src';

/// Returns the layer of [path], a POSIX path relative to `lib/src`.
String _layer(String path) =>
    p.posix.withoutExtension(p.posix.split(path).first);

/// Returns the path relative to `lib/src` that [uri], written in the file at
/// [from], points to, or `null` if it points outside `lib/src`.
String? _target(String uri, {required String from}) {
  final parsed = Uri.parse(uri);
  if (parsed.scheme == 'package') {
    final segments = parsed.pathSegments;
    if (segments.length < 3 ||
        segments[0] != 'vaixell' ||
        segments[1] != 'src') {
      return null;
    }
    return p.posix.joinAll(segments.skip(2));
  }
  if (parsed.hasScheme) return null;
  final resolved = p.posix.normalize(p.posix.join(p.posix.dirname(from), uri));
  return p.posix.isWithin('.', resolved) ? resolved : null;
}

/// Returns the Dart files in [directory] and its subdirectories.
Iterable<File> _dartFiles(String directory) =>
    Directory(directory)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

/// Returns the URIs of the import, export and part directives in [file].
Iterable<String> _uris(File file) =>
    parseString(content: file.readAsStringSync()).unit.directives
        .whereType<UriBasedDirective>()
        .map((directive) => directive.uri.stringValue!);

void main() {
  test('lib/src imports only follow the allowed layering', () {
    final violations = <String>[];
    for (final file in _dartFiles(_src)) {
      final path = p.posix.joinAll(p.split(p.relative(file.path, from: _src)));
      final layer = _layer(path);
      final allowed = _allowedImports[layer];
      if (allowed == null) {
        violations.add('$path: layer "$layer" is not in the layering');
        continue;
      }

      for (final uri in _uris(file)) {
        final target = _target(uri, from: path);
        if (target == null) continue;
        final targetLayer = _layer(target);
        if (targetLayer != layer && !allowed.contains(targetLayer)) {
          violations.add('$path: $layer must not import $targetLayer ($uri)');
        }
      }
    }

    expect(violations, isEmpty);
  });

  test('lib/src/check imports no CLI packages or reporters', () {
    final forbidden = RegExp(
      r'^package:(args|mason_logger|io)/|reporter\.dart$',
    );
    final violations = [
      for (final file in _dartFiles(p.join(_src, 'check')))
        for (final uri in _uris(file))
          if (forbidden.hasMatch(uri)) '${file.path}: $uri',
    ];

    expect(violations, isEmpty);
  });
}
