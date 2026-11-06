import 'package:test/test.dart';
import 'package:vaixell/src/model/model.dart';

DartFile _parse(
  String content, {
  String path = 'lib/a.dart',
  String packageRoot = '',
  String? packageName,
}) => DartFile.parse(
  path: path,
  content: content,
  packageRoot: packageRoot,
  packageName: packageName,
);

void main() {
  group(DartFile, () {
    test('gives the 1-based line and column of an offset', () {
      const source = 'class A {}\nclass B {}\n';
      final file = _parse(source);
      final offset = source.indexOf('B');
      expect((file.lineAt(offset), file.columnAt(offset)), (2, 7));
      expect((file.lineAt(0), file.columnAt(0)), (1, 1));
    });

    group('paths', () {
      test('keeps the repo-relative path', () {
        expect(_parse('', path: 'lib/src/a.dart').path, 'lib/src/a.dart');
      });

      test('is relative to the package root', () {
        final file = _parse(
          '',
          path: 'packages/app/lib/src/a.dart',
          packageRoot: 'packages/app',
        );
        expect(file.packagePath, 'lib/src/a.dart');
      });

      test('is the path itself for the root package', () {
        expect(_parse('', path: 'lib/b.dart').packagePath, 'lib/b.dart');
      });

      test('lists the directories of the path', () {
        final file = _parse('', path: 'packages/app/lib/models/a.dart');
        expect(file.directories, ['packages', 'app', 'lib', 'models']);
        expect(file.directories, same(file.directories));
        expect(file.directories.clear, throwsUnsupportedError);
      });

      test('has no directories for a file at the root', () {
        expect(_parse('', path: 'a.dart').directories, isEmpty);
      });
    });

    group('errors', () {
      test('are empty when the file parses', () {
        expect(_parse('class A {}\n').errors, isEmpty);
      });

      test('are in source order, without a symbol', () {
        const source = 'class A { void f( }\nclass {\n';
        final errors = _parse(source).errors;
        expect(errors, hasLength(greaterThan(1)));
        expect(errors.map((e) => e.symbol), everyElement(isNull));
        expect(errors.map((e) => e.message), everyElement(isNotEmpty));
        final offsets = errors.map((e) => e.offset).toList();
        expect(offsets, orderedEquals([...offsets]..sort()));
      });
    });

    group('imports', () {
      const source =
          'library;\n'
          "import 'dart:async';\n"
          "import 'package:flutter/material.dart' as m;\n"
          "export 'b.dart';\n"
          "import '../b.dart';\n"
          "part 'c.dart';\n";

      test('are the import directives, in source order', () {
        final imports = _parse(source).imports;
        expect(imports.map((i) => i.uri), [
          'dart:async',
          'package:flutter/material.dart',
          '../b.dart',
        ]);
        expect(imports.map((i) => i.kind), [
          ImportKind.dart,
          ImportKind.package,
          ImportKind.relative,
        ]);
      });

      test('are at the import keyword, with their URI as symbol', () {
        final import = _parse(source).imports[1];
        expect(import.offset, source.indexOf("import 'package:"));
        expect(import.symbol, 'package:flutter/material.dart');
      });

      test('keep the same objects on every read', () {
        final file = _parse(source);
        expect(file.imports.first, same(file.imports.first));
      });

      test('have an empty URI when it is not a plain string', () {
        final file = _parse(
          r"import '$a';"
          '\n',
        );
        expect(file.imports.single.uri, isEmpty);
        expect(file.imports.single.path, isNull);
      });

      group('path', () {
        String? pathOf(
          String uri, {
          String path = 'packages/app/lib/src/a.dart',
          String? packageName = 'app',
        }) => _parse(
          "import '$uri';\n",
          path: path,
          packageRoot: 'packages/app',
          packageName: packageName,
        ).imports.single.path;

        test('resolves relative imports from the file', () {
          expect(pathOf('b.dart'), 'packages/app/lib/src/b.dart');
          expect(pathOf('../b/c.dart'), 'packages/app/lib/b/c.dart');
          expect(pathOf('./b.dart'), 'packages/app/lib/src/b.dart');
        });

        test('resolves imports of the own package', () {
          expect(
            pathOf('package:app/src/b.dart'),
            'packages/app/lib/src/b.dart',
          );
        });

        test('resolves own-package imports in the root package', () {
          final file = _parse(
            "import 'package:app/b.dart';\n",
            packageName: 'app',
          );
          expect(file.imports.single.path, 'lib/b.dart');
        });

        test('is null for other packages and dart: imports', () {
          expect(pathOf('package:other/b.dart'), isNull);
          expect(pathOf('package:application/b.dart'), isNull);
          expect(pathOf('dart:async'), isNull);
        });

        test('is null for package imports when the name is unknown', () {
          expect(pathOf('package:app/b.dart', packageName: null), isNull);
        });
      });
    });
  });
}
