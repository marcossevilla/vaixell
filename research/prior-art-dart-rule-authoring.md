# Prior art: AST-free rule authoring in Dart tools

Research for [#34](https://github.com/marcossevilla/vaixell/issues/34), map
[#33](https://github.com/marcossevilla/vaixell/issues/33). Dart tools only.
Sources read from the pub cache (versions below) and the archived
dart-code-metrics repo.

## Headline

**No Dart tool offers an AST-free rule API.** Every tool surveyed hands rule
authors analyzer AST nodes or raw parser tokens. A vaixell-owned model would
be new in the Dart ecosystem, so there is no model to copy. There are patterns
for rule shape, options and registration worth borrowing, though.

## Tools

### custom_lint (`custom_lint_core` 0.8.1, `custom_lint_builder` 0.7.6)

- **Shape:** `DartLintRule` with a `LintCode`, and
  `run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context)`.
  Rules register AST callbacks: `context.registry.addMethodInvocation((node) {...})`.
  All rules share one `LinterVisitor` pass over the resolved unit.
- **Model:** the resolved analyzer AST and elements. Helpers like
  `TypeChecker.fromName('Foo', packageName: 'bar')` hide some element-model
  details, but authors work on the AST directly.
- **Reporting:** `reporter.atNode(node, code)` / `atToken` / `atOffset`.
- **Options:** `configs.rules[code.name]?.json` is an untyped
  `Map<String, Object?>` from `custom_lint: rules: - rule_name: {...}`, nested
  under the rule. No schema, no validation, no source positions for errors.
- **Registration:** a plugin package exposes `createPlugin()` returning a
  `PluginBase` with `List<LintRule> getLintRules(CustomLintConfigs configs)`.
  Rules are built _from_ the configs, so options can be passed in at
  construction.
- `CustomLintContext.pubspec` exposes the analyzed package's pubspec, so a
  rule can turn itself off based on dependencies.

### analysis_server_plugin (0.3.14) and the SDK linter (`analyzer` 14.7.0)

- **Shape:** `AnalysisRule({name, description, state})` with a
  `DiagnosticCode` and `registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context)`.
  Each rule writes a `SimpleAstVisitor` and registers it per node type
  (`registry.addMethodInvocation(this, visitor)`). SDK lints use the same
  base class.
- **Model:** resolved AST plus elements (`RuleContext.typeProvider`,
  `typeSystem`, `libraryElement`, `allUnits`, `package`, `isInLibDir`,
  `isInTestDirectory`).
- **Reporting:** `rule.reportAtNode(node)`, `reportAtToken`, `reportAtOffset`,
  `reportAtSourceRange`, with message arguments filled into the code's
  template.
- **Options:** none per rule. Analysis options only enable or disable a
  diagnostic.
- **Registration:** a `Plugin` subclass implements `register(PluginRegistry registry)`
  and calls `registry.registerWarningRule(rule)` or `registerLintRule(rule)`.
  This is injection through a registry object.

### bloc_lint (0.4.3)

- **Shape:** `abstract class LintRule { name; severity; Listener? create(LintContext context); }`.
  `create` returns `null` to skip a file.
- **Model:** parse-only, _below_ the AST. Rules subclass the shared front-end
  parser `Listener` (`package:_fe_analyzer_shared`, an implementation import)
  and react to token events such as `beginImport(Token importKeyword)`.
  `LintContext.document` is a `TextDocument` that classifies the file
  (`type.isBloc`, `isCubit`, `isOther`, inferred from the file name). That's
  the only domain-level model in the tools surveyed.
- **Reporting:** `context.reportToken(token: ..., message: ..., hint: ...)` or
  `report(range: Range(...))`. Line-level `// ignore:` is handled in the
  context.
- **Options:** severity only (`bloc: rules: {rule: warning}`), parsed with
  `json_serializable` + `checked_yaml`.
- **Registration:** a closed map,
  `allRules = {AvoidFlutterImports.rule: AvoidFlutterImports.new, ...}`, of
  `LintRule Function([Severity?])` builders.
- `avoid_flutter_imports` matches the raw import string against
  `package:flutter/` and only runs on bloc/cubit files. It's a special case of
  #32.

### DCM / dart_code_metrics (archived open-source version)

Source: https://github.com/dart-code-checker/dart-code-metrics (archived; DCM
is closed-source now).

- **Shape:** `abstract class Rule { id; type; severity; excludes; includes; bool get requiresConfig; Iterable<Issue> check(InternalResolvedUnitResult source); }`.
  It's a single `check` that returns issues, the same shape vaixell decided on
  in [Shape of a rule](https://github.com/marcossevilla/vaixell/issues/40).
- **Model:** `InternalResolvedUnitResult` wraps the resolved unit but exposes
  `unit` (the AST). Rules write `RecursiveAstVisitor`s.
- **Reporting:** `createIssue(rule:, location: nodeLocation(node:, source:), message:)`.
  Rules build an issue themselves, as vaixell's rules build `Finding`.
- **Options:** nested under the rule (`rules: - avoid-banned-imports: {entries: [...]}`).
  Each rule's constructor takes `Map<String, Object> config` and parses it
  (`_ConfigParser`), with hard casts and no positioned errors. Shared helpers
  read `severity`, `exclude` and `include` from every rule's config.
  `requiresConfig` marks rules that are useless without options.
- **Registration:** a closed factory map, rule id → `Rule Function(Map<String, Object> config)`.
- `avoid-banned-imports` is close to #32: `entries: [{paths: [regex], deny: [regex], message}]`,
  matched against the raw import URI, with no relative-import resolution.

## Patterns relevant to vaixell

1. **Construct rules from their options.** custom_lint (`getLintRules(configs)`),
   DCM (`Rule(config)`) and bloc_lint (`builder(severity)`) all build rule
   instances from config instead of passing options to every `check`. For
   [Dart API for rule options](https://github.com/marcossevilla/vaixell/issues/38),
   this is an alternative to `check(file, options)`: a rule _factory_, keyed
   by id, takes the parsed options and returns a configured rule. Because
   vaixell config is per package, that means one instance per package.
2. **Typed, positioned option errors are a gap.** Every tool that has options
   reads an untyped map and hard-casts it. A `ConfigValue` wrapper that keeps
   YAML spans would beat all of them.
3. **A "requires config" flag.** DCM's `requiresConfig` matches #32's "off in
   `recommended`, since it does nothing without config".
4. **Severity, include and exclude read by the framework.** DCM pulls these out
   of every rule's options before the rule sees them. This matches the
   decision in [Where rule options live in config](https://github.com/marcossevilla/vaixell/issues/43)
   that a rule sees its entry minus `severity`.
5. **Registration through a registry or factory map.** analysis_server_plugin's
   `register(PluginRegistry)` is the injection shape. DCM and bloc_lint use
   closed maps of id → factory, which is what vaixell's `RuleRegistry` is
   today. A list or map of factories passed to the engine fits
   [How rules reach the engine](https://github.com/marcossevilla/vaixell/issues/42).
6. **Skip a file early.** bloc_lint's `create` returns `null` for files a rule
   doesn't care about, and DCM uses per-rule `includes`/`excludes`. A model
   that exposes file path facts (path, package-relative path, directories)
   makes this a one-line guard. `raw-json` already does it for `models/`.
7. **File-level classification is the one domain model with prior art.**
   bloc_lint's `TextDocument.type` and analysis_server_plugin's
   `isInLibDir`/`isInTestDirectory` show that file facts are worth putting on
   the model, apart from syntax.
8. **Declaration-level wrappers are easy; expression-level ones are not.**
   No tool hides expressions. Even custom_lint's helpers stop at types. This
   confirms that the
   [Expression-level model](https://github.com/marcossevilla/vaixell/issues/36)
   is the crux and needs its own design; prior art won't answer it.

## Sources

- `custom_lint_core` 0.8.1: `lib/src/lint_rule.dart`, `lib/src/configs.dart`, `lib/src/plugin_base.dart`
- `analyzer` 14.7.0: `lib/src/analysis_rule/analysis_rule.dart`, `rule_context.dart`
- `analysis_server_plugin` 0.3.14: `lib/plugin.dart`, `lib/registry.dart`
- `bloc_lint` 0.4.3: `lib/src/lint_rule.dart`, `lib/src/linter.dart`, `lib/src/rules/avoid_flutter_imports.dart`
- dart-code-metrics: [`rules/models/rule.dart`](https://github.com/dart-code-checker/dart-code-metrics/blob/master/lib/src/analyzers/lint_analyzer/rules/models/rule.dart), [`avoid_banned_imports_rule.dart`](https://github.com/dart-code-checker/dart-code-metrics/blob/master/lib/src/analyzers/lint_analyzer/rules/rules_list/avoid_banned_imports/avoid_banned_imports_rule.dart)
