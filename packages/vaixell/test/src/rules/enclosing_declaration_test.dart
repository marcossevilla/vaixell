import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:vaixell/src/model/model.dart' show AstBridge;
import 'package:vaixell/src/rules/enclosing_declaration.dart';

import '../../helpers/parse.dart';

class _StringLiterals extends RecursiveAstVisitor<void> {
  final List<SimpleStringLiteral> literals = [];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    literals.add(node);
  }
}

void main() {
  group(EnclosingDeclaration, () {
    const enclosing = EnclosingDeclaration();

    /// Returns the symbol of every string literal in [source], in order.
    List<String?> symbols(String source) {
      final visitor = _StringLiterals();
      const AstBridge().unitOf(parse(source)).accept(visitor);
      return visitor.literals.map(enclosing.symbolOf).toList();
    }

    test('names members after their container', () {
      expect(
        symbols('''
class C {
  C() { ''; }
  C.named() { ''; }
  final field = '';
  void method() {
    void local() => '';
    final x = () => '';
  }
  String get property => '';
  set property(String v) { ''; }
}
mixin M { void m() => ''; }
enum E { a; void m() => ''; }
extension X on int { void m() => ''; }
extension on int { void m() => ''; }
extension type T(int v) { void m() => ''; }
'''),
        equals([
          'C.new',
          'C.named',
          'C.field',
          'C.method',
          'C.method',
          'C.property',
          'C.property=',
          'M.m',
          'E.m',
          'X.m',
          '<unnamed>.m',
          'T.m',
        ]),
      );
    });

    test('names top-level functions and variables', () {
      expect(
        symbols('''
final top = '';
void function() => '';
String get getter => '';
set setter(String v) { ''; }
'''),
        equals(['top', 'function', 'getter', 'setter=']),
      );
    });

    test('uses the first variable for a shared type annotation', () {
      final unit = const AstBridge().unitOf(
        parse('Map<String, dynamic> a = {}, b = {};\n'),
      );
      final list =
          (unit.declarations.single as TopLevelVariableDeclaration).variables;
      expect(enclosing.symbolOf(list.type!), equals('a'));
      expect(enclosing.symbolOf(list.variables.last), equals('b'));
    });

    test('names only the container outside a member', () {
      expect(symbols("@A('')\nclass C {}\n"), equals(['C']));
    });

    test('returns null at the top of the file', () {
      expect(symbols("@A('')\nlibrary;\n"), equals([null]));
    });
  });
}
