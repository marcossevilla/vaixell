// PROTOTYPE: forbidden-import is new, so there's no rule today to compare
// it with. These tests pin the #32 sketch on the model.

import 'package:test/test.dart';

import '../../test/helpers/parse.dart';
import '../declaration_rules.dart';
import '../model.dart';

void main() {
  group(ForbiddenImportRule, () {
    const rule = ForbiddenImportRule([
      ImportBoundary(files: 'lib/domain/**', forbid: ['package:flutter/']),
      ImportBoundary(
        files: '**/*_bloc.dart',
        forbid: ['package:flutter/', 'packages/app/lib/data/'],
      ),
    ]);

    List<String?> symbols(String source, {required String path}) => [
      for (final finding in rule.check(
        modelOf(
          parse(source, path: path),
          packageRoot: 'packages/app',
          packageName: 'app',
        ),
      ))
        finding.symbol,
    ];

    test('has the expected id', () {
      expect(rule.id, equals('forbidden-import'));
    });

    test('flags forbidden URIs in matching files, at the import keyword', () {
      const source =
          "import 'dart:async';\n"
          "import 'package:flutter/material.dart';\n";
      final findings = rule.check(
        modelOf(
          parse(source, path: 'packages/app/lib/domain/user.dart'),
          packageRoot: 'packages/app',
        ),
      );
      expect(findings.map((f) => f.symbol), ['package:flutter/material.dart']);
      expect(findings.single.offset, source.lastIndexOf('import'));
      expect(
        findings.single.message,
        '`package:flutter/material.dart` is not allowed in `lib/domain/**`. '
        'Move the code that needs it out of this layer.',
      );
    });

    test('ignores files outside every boundary', () {
      expect(
        symbols(
          "import 'package:flutter/material.dart';\n",
          path: 'packages/app/lib/ui/page.dart',
        ),
        isEmpty,
      );
    });

    test('matches the repo path of relative and own-package imports', () {
      expect(
        symbols(
          "import '../data/api.dart';\n"
          "import 'package:app/data/db.dart';\n"
          "import 'package:other/data/db.dart';\n"
          "import '../domain/user.dart';\n",
          path: 'packages/app/lib/user/user_bloc.dart',
        ),
        ['../data/api.dart', 'package:app/data/db.dart'],
      );
    });
  });
}
