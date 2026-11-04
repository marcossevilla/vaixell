import 'package:test/test.dart';
import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/rule.dart';

void main() {
  group(Finding, () {
    group('at', () {
      const source = "import 'dart:async';\n";
      final import = const DartFileParser()
          .parse(path: 'lib/a.dart', content: source)
          .imports
          .single;
      final error = const DartFileParser()
          .parse(path: 'lib/a.dart', content: 'class A {\n')
          .errors
          .first;

      test("takes the element's offset and symbol", () {
        final finding = Finding.at(import, message: 'm');
        expect(finding.offset, import.offset);
        expect(finding.message, 'm');
        expect(finding.symbol, 'dart:async');
      });

      test('appends the qualifier to the symbol', () {
        final finding = Finding.at(import, message: 'm', qualifier: 'q');
        expect(finding.symbol, 'dart:async@q');
      });

      test('keeps a null symbol without a qualifier', () {
        expect(Finding.at(error, message: 'm').symbol, isNull);
      });

      test('uses only the qualifier when the element has no symbol', () {
        final finding = Finding.at(error, message: 'm', qualifier: 'q');
        expect(finding.offset, error.offset);
        expect(finding.symbol, '@q');
      });
    });
  });
}
