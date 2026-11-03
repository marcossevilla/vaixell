// PROTOTYPE: runs the rules in rules.dart through today's `Rule` interface,
// under today's names, so today's tests can run against them unchanged.

import 'package:vaixell/src/rules/rule.dart';
import 'package:vaixell/src/violation/violation.dart';

import '../model.dart';
import '../rules.dart' as model;

base class _Shim extends Rule {
  const _Shim(this._rule, this.defaultSeverity);

  final model.ModelRule _rule;

  @override
  final Severity defaultSeverity;

  @override
  String get id => _rule.id;

  @override
  List<Finding> check(ParsedFile file) => _rule.check(modelOf(file));
}

final class AwaitReceiverRule extends _Shim {
  const AwaitReceiverRule()
    : super(const model.AwaitReceiverRule(), Severity.warning);
}

final class RawJsonRule extends _Shim {
  const RawJsonRule() : super(const model.RawJsonRule(), Severity.error);
}

final class GeneratedJsonRule extends _Shim {
  const GeneratedJsonRule()
    : super(const model.GeneratedJsonRule(), Severity.warning);
}
