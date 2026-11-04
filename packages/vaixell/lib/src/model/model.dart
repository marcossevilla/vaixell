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
part 'ast_declarations.dart';
part 'ast_expressions.dart';
part 'dart_file.dart';
part 'declarations.dart';
part 'expressions.dart';
part 'import.dart';
part 'reportable.dart';
part 'type_annotations.dart';
