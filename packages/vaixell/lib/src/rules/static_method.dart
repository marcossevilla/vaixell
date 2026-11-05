import 'package:vaixell/src/model/model.dart';
import 'package:vaixell/src/rules/rule.dart';

/// Reports static methods, getters and setters, public or private, in
/// classes, mixins, enums, extensions and extension types.
///
/// Static fields and factory constructors aren't methods, so they aren't
/// reported.
final class const StaticMethodRule() extends Rule with ChecksMembers {
  /// Creates the rule.
  this;

  @override
  String get id => 'static-method';

  @override
  Finding? checkMember(TypeDeclaration type, Member member) => switch (member) {
    Method(isStatic: true, :final kind, :final name) => Finding.at(
      member,
      message:
          'Static ${kind.asMember} `${type.name ?? '<unnamed>'}.$name` is not '
          'allowed. Use an instance member instead.',
    ),
    _ => null,
  };
}
