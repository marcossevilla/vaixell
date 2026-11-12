/// The model of a Dart file that rules check, so that no rule touches the
/// analyzer AST.
///
/// Every public type is vaixell's. The `ast_*.dart` parts wrap the
/// parse-only AST in private classes; they are parts because the model's
/// families are sealed, so only this library can implement them.
library;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as p;

part 'ast_dart_file.dart';
part 'dart_file.dart';
part 'declarations/annotations.dart';
part 'declarations/ast_annotations.dart';
part 'declarations/ast_declarations.dart';
part 'declarations/ast_members.dart';
part 'declarations/declarations.dart';
part 'declarations/members.dart';
part 'expressions/ast_collector.dart';
part 'expressions/ast_enclosed.dart';
part 'expressions/ast_expressions.dart';
part 'expressions/ast_type_annotations.dart';
part 'expressions/enclosed.dart';
part 'expressions/expressions.dart';
part 'expressions/type_annotations.dart';
part 'expressions/uses.dart';
part 'ignores.dart';
part 'imports/ast_import.dart';
part 'imports/import.dart';
part 'reportable.dart';
part 'syntax_error.dart';
