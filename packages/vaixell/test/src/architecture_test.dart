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
  'version': {},
  'command_runner': {'commands', 'version'},
  'commands': {
    'baseline',
    'command_runner',
    'config',
    'discovery',
    'engine',
    'git',
    'report',
    'source',
    'version',
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

void main() {
  test('lib/src imports only follow the allowed layering', () {
    final violations = <String>[];
    final files = Directory(_src)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final path = p.posix.joinAll(p.split(p.relative(file.path, from: _src)));
      final layer = _layer(path);
      final allowed = _allowedImports[layer];
      if (allowed == null) {
        violations.add('$path: layer "$layer" is not in the layering');
        continue;
      }

      final unit = parseString(content: file.readAsStringSync()).unit;
      for (final directive in unit.directives.whereType<UriBasedDirective>()) {
        final uri = directive.uri.stringValue!;
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
}
