import 'package:vaixell/src/rules/rule.dart';

/// A rule that ships with vaixell, documented at `docs/rules/<id>.md` in
/// vaixell's repository.
///
/// It isn't part of the public API: only rules in vaixell mix it in, since
/// a rule outside vaixell has no page there to link to.
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
  ///
  /// It links to `main` rather than a release tag on purpose, so every
  /// version points at the latest docs of its rules.
  Uri get url => Uri.parse(
    'https://github.com/marcossevilla/vaixell/blob/main/docs/rules/$id.md',
  );
}
