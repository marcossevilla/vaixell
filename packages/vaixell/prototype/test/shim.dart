// PROTOTYPE: runs the prototype rules through today's `Rule` interface,
// under today's names, so today's tests can run against them unchanged.

import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

import '../declaration_rules.dart' as model;
import '../model.dart';
import '../rule.dart' show ModelRule;
import '../rules.dart' as model;

base class const _Shim(
  final ModelRule _rule,
  @override final Severity defaultSeverity, {
  @override final bool checksFilesWithErrors = false,
}) extends Rule {
  @override
  String get id => _rule.id;

  @override
  List<Finding> check(ParsedFile file) => [
    for (final f in _rule.check(modelOf(file)))
      Finding(offset: f.offset, message: f.message, symbol: f.symbol),
  ];
}

final class const AwaitReceiverRule() extends _Shim {
  this : super(const model.AwaitReceiverRule(), Severity.warning);
}

final class const RawJsonRule() extends _Shim {
  this : super(const model.RawJsonRule(), Severity.error);
}

final class const GeneratedJsonRule() extends _Shim {
  this : super(const model.GeneratedJsonRule(), Severity.warning);
}

final class const StaticMethodRule() extends _Shim {
  this : super(const model.StaticMethodRule(), Severity.error);
}

final class const TopLevelFunctionRule() extends _Shim {
  this : super(const model.TopLevelFunctionRule(), Severity.error);
}

final class const TopLevelVariableRule() extends _Shim {
  this : super(const model.TopLevelVariableRule(), Severity.error);
}

final class const ExtensionDeclarationRule() extends _Shim {
  this : super(const model.ExtensionDeclarationRule(), Severity.error);
}

final class const ParseErrorRule() extends _Shim {
  this
    : super(
        const model.ParseErrorRule(),
        Severity.error,
        checksFilesWithErrors: true,
      );
}
