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
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as p;

part 'ast_dart_file.dart';
part 'dart_file.dart';
part 'import.dart';
part 'reportable.dart';
