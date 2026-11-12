import 'package:vaixell/src/rules/rule.dart';

/// A rule that ships with vaixell, documented at `docs/rules/<id>.md` in
/// vaixell's repository.
///
/// It isn't exported, so rules written outside vaixell have no [docs].
base mixin BuiltInRule on Rule {
  /// The page that documents this rule.
  Uri get docs => RuleDocs(id).url;
}

/// The page in vaixell's repository that documents the rule [id].
final class const RuleDocs(
  /// The id of the documented rule, such as `parse-error`.
  final String id,
) {
  /// Creates the docs of the rule [id].
  this;

  /// The URL of the page on `main`.
  Uri get url => Uri.parse(
    'https://github.com/marcossevilla/vaixell/blob/main/docs/rules/$id.md',
  );
}
