import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The `lib/src` layers each layer may import, besides itself.
///
/// A layer is a directory under `lib/src`, or a file directly in it.
const _allowedImports = <String, Set<String>>{
  'violation': {},
  'model': {},
  'options': {},
  'rules': {'model', 'options', 'violation'},
  'config': {'options', 'rules', 'source', 'violation'},
  'source': {'git'},
  'engine': {'config', 'model', 'rules', 'source', 'violation'},
  'report': {'engine', 'violation'},
  'testing': {'model', 'options', 'rules'},
  'baseline': {},
  'discovery': {'config', 'options', 'source'},
  'git': {},
  'check': {
    'baseline',
    'config',
    'discovery',
    'engine',
    'git',
    'report',
    'rules',
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

/// The types, besides vaixell's own and type parameters, that a public
/// signature may use: the SDK's and those of the packages vaixell builds on,
/// other than `analyzer` and `yaml`.
const _allowedForeignTypes = {
  'bool',
  'int',
  'double',
  'num',
  'String',
  'Object',
  'Never',
  'Null',
  'dynamic',
  'void',
  'List',
  'Set',
  'Map',
  'Iterable',
  'Future',
  'Stream',
  'Function',
  'Exception',
  'Error',
  'StringSink',
  'Uri',
  'Directory',
  'File',
  'Process',
  'ProcessResult',
  'Glob',
};

/// The packages whose types must not be in vaixell's public API.
final _forbiddenPackages = RegExp('^package:(analyzer|yaml)/');

/// The declarations [library] exports, by file and shown names.
Map<String, Set<String>> _exports(String library) {
  final unit = parseString(content: File(library).readAsStringSync()).unit;
  return {
    for (final directive in unit.directives.whereType<ExportDirective>())
      p.join(p.dirname(library), directive.uri.stringValue): {
        for (final combinator
            in directive.combinators.whereType<ShowCombinator>())
          for (final name in combinator.shownNames) name.name,
      },
  };
}

/// The units of the library at [path]: the file itself and its parts.
List<CompilationUnit> _units(String path) {
  final unit = parseString(content: File(path).readAsStringSync()).unit;
  return [
    unit,
    for (final part in unit.directives.whereType<PartDirective>())
      parseString(
        content: File(p.join(p.dirname(path), part.uri.stringValue))
            .readAsStringSync(),
      ).unit,
  ];
}

/// The names of the types vaixell declares in `lib/`.
Set<String> _declaredTypes() => {
  for (final file in _dartFiles('lib'))
    for (final declaration in parseString(
      content: file.readAsStringSync(),
    ).unit.declarations)
      switch (declaration) {
        ClassDeclaration(:final namePart) ||
        EnumDeclaration(:final namePart) ||
        ExtensionTypeDeclaration(:final namePart) => namePart.typeName.lexeme,
        MixinDeclaration(:final name) || TypeAlias(:final name) => name.lexeme,
        _ => '',
      },
};

/// Collects the types in the public signatures of a declaration: no
/// bodies, initializers, default values, annotations or private members.
class _SignatureTypes extends RecursiveAstVisitor<void> {
  final List<NamedType> types = [];
  final Set<String> typeParameters = {};

  bool _isPrivate(Token? name) => name?.lexeme.startsWith('_') ?? false;

  @override
  void visitNamedType(NamedType node) {
    types.add(node);
    super.visitNamedType(node);
  }

  @override
  void visitTypeParameter(TypeParameter node) {
    typeParameters.add(node.name.lexeme);
    super.visitTypeParameter(node);
  }

  @override
  void visitPrimaryConstructorDeclaration(PrimaryConstructorDeclaration node) {
    if (!_isPrivate(node.constructorName?.name)) {
      node.formalParameters.accept(this);
    }
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (!_isPrivate(node.name)) node.parameters.accept(this);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (_isPrivate(node.name)) return;
    node.returnType?.accept(this);
    node.typeParameters?.accept(this);
    node.parameters?.accept(this);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    node.returnType?.accept(this);
    node.functionExpression.typeParameters?.accept(this);
    node.functionExpression.parameters?.accept(this);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.fields.variables.every((v) => _isPrivate(v.name))) return;
    node.fields.type?.accept(this);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) =>
      node.variables.type?.accept(this);

  @override
  void visitFormalParameterDefaultClause(FormalParameterDefaultClause node) {}

  @override
  void visitAnnotation(Annotation node) {}

  @override
  void visitComment(Comment node) {}
}

void main() {
  group('lib/src', () {
    test('imports only follow the allowed layering', () {
      final violations = <String>[];
      for (final file in _dartFiles(_src)) {
        final path = p.posix.joinAll(
          p.split(p.relative(file.path, from: _src)),
        );
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

    test('keeps check free of CLI packages and reporters', () {
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
  });

  group('public API', () {
    test('only the model imports package:analyzer', () {
      final violations = [
        for (final file in _dartFiles(_src))
          if (!p.isWithin(p.join(_src, 'model'), file.path))
            for (final uri in _uris(file))
              if (uri.startsWith('package:analyzer/')) '${file.path}: $uri',
      ];

      expect(violations, isEmpty);
    });

    for (final library in ['lib/vaixell.dart', 'lib/testing.dart']) {
      test('$library exposes no analyzer or yaml types', () {
        final declared = _declaredTypes();
        final violations = <String>[];
        for (final MapEntry(key: path, value: shown) in _exports(
          library,
        ).entries) {
          final units = _units(path);
          final prefixes = {
            for (final directive
                in units.first.directives.whereType<ImportDirective>())
              if (directive.prefix case final prefix?)
                prefix.name: directive.uri.stringValue!,
          };
          for (final unit in units) {
            for (final declaration in unit.declarations) {
              final name = switch (declaration) {
                MixinDeclaration(:final name) ||
                FunctionDeclaration(:final name) ||
                TypeAlias(:final name) => name.lexeme,
                ClassDeclaration(:final namePart) ||
                EnumDeclaration(:final namePart) ||
                ExtensionTypeDeclaration(
                  :final namePart,
                ) => namePart.typeName.lexeme,
                TopLevelVariableDeclaration(:final variables) =>
                  variables.variables.first.name.lexeme,
                _ => null,
              };
              if (!shown.contains(name)) continue;
              final visitor = _SignatureTypes();
              declaration.accept(visitor);
              for (final type in visitor.types) {
                final prefix = type.importPrefix?.name.lexeme;
                final foreign = prefix == null
                    ? !declared.contains(type.name.lexeme) &&
                          !_allowedForeignTypes.contains(type.name.lexeme) &&
                          !visitor.typeParameters.contains(type.name.lexeme)
                    : _forbiddenPackages.hasMatch(prefixes[prefix] ?? '');
                if (foreign) {
                  violations.add('$path: $name uses ${type.toSource()}');
                }
              }
            }
          }
        }

        expect(violations, isEmpty);
      });
    }
  });
}
