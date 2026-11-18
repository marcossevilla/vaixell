import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/built_in_rule.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Reports extensions on a type that the same file declares, whose members
/// belong on the type itself.
///
/// Extensions on other types and extension types are allowed.
final class const ExtensionDeclarationRule() extends Rule with BuiltInRule {
  /// Creates the rule.
  this;

  @override
  String get id => 'extension-declaration';

  @override
  List<Finding> check(DartFile file) {
    final declared = {
      for (final declaration in file.declarations)
        if (declaration case TypeDeclaration(:final name?)
            when declaration is! ExtensionDeclaration)
          name,
    };
    return [
      for (final declaration in file.declarations)
        if (declaration
            case ExtensionDeclaration(
              extendedType: TypeAnnotation(prefix: null, name: final type?),
            )
            when declared.contains(type))
          Finding.at(
            declaration,
            message: switch (declaration.name) {
              null =>
                'This extension adds members to `$type`, which this '
                    'file declares. Add them to `$type` instead.',
              final name =>
                'Extension `$name` adds members to `$type`, which '
                    'this file declares. Add them to `$type` instead.',
            },
          ),
    ];
  }
}
