// PROTOTYPE: runs the rules in rules.dart through today's `Rule` interface,
// under today's names, so today's tests can run against them unchanged.

import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

import '../model.dart';
import '../rule.dart' show ModelRule;
import '../rules.dart' as model;

base class const _Shim(
  final ModelRule _rule,
  @override final Severity defaultSeverity,
) extends Rule {
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
