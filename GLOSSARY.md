# vaixell

vaixell checks architecture rules in Dart and Flutter repositories, parsing files without resolving types.

## Rules

**Rule** (`Rule`):
An architecture constraint, identified by an id, that reads one Dart file and returns findings.
_Avoid_: lint, check, model rule

**Rule factory** (`RuleFactory`):
Builds a configured rule from one package's rule options. Rules that take options are registered this way.
_Avoid_: rule builder, configurable rule

**Rule entry** (`RuleEntry`):
What vaixell is given for each rule id: a rule, or a rule factory when the rule takes options.
_Avoid_: injected entry, rule provider, rule source

**Rule options** (`OptionValue`):
The settings under a rule's id in a package's config, other than its severity.
_Avoid_: rule config, rule settings, parameters

**Built-in rule** (`Recommended.rules`):
A rule that ships with vaixell, such as `static-method` or `raw-json`. The CLI checks them by default; other callers can extend the list or remove rules from it.
_Avoid_: core rule, default rule

## Configuration

**Package**:
A Dart package in the repository, with its own `vaixell:` config, checked on its own.
_Avoid_: project, module

**Severity** (`Severity`):
Whether a rule's violations fail the run (`error`) or are only reported (`warning`).
_Avoid_: level, priority

**Preset**:
A named set of rules at their default severities that a package's config includes, such as `recommended`.
_Avoid_: profile, ruleset

**Baseline** (`Baseline`):
A file of violation ids that are known and accepted, so only new violations are reported.
_Avoid_: allowlist, ignore list, snapshot

**Ignore comment** (`Ignores`):
A `// ignore:` comment that turns rules off on one line, or a `// ignore_for_file:` comment that turns them off in the whole file.
_Avoid_: suppression, exemption, pragma

## Findings

**Finding** (`Finding`):
What a rule reports at one place in a file: an offset, a message and an optional symbol.
_Avoid_: issue, lint, diagnostic, problem

**Violation** (`Violation`):
A finding after vaixell gives it a violation id, a severity and a line and column.
_Avoid_: error, issue

**Violation id**:
The stable identity of a violation, made of the rule id, the file's path and the finding's symbol, without line numbers.
_Avoid_: key, fingerprint

**Symbol**:
The name of what a finding points at within its file, such as `Container.member`, `member` or `Container`.
_Avoid_: path, element name

**Qualifier**:
The part a rule appends to a symbol after `@` to tell apart findings in the same place, as in `ApiClient.getUser@decode`.
_Avoid_: suffix, tag

## The model

**Dart file** (`DartFile`):
One parsed Dart file as a rule sees it: its path, imports, syntax errors, declarations, expressions and type annotations.
_Avoid_: parsed file, source file, compilation unit

**Reportable** (`Reportable`):
A part of a Dart file that a finding can point at, because it has an offset and a symbol.
_Avoid_: located, element, node

**Enclosed** (`Enclosed`):
An expression or type annotation, seen together with the declaration and member it is written in.
_Avoid_: code, nested, inner

**Reference** (`Reference`):
An expression that reads a name without calling it, optionally through a target, as in `name` or `target.name`.
_Avoid_: identifier, property access, name reference

**Type annotation** (`TypeAnnotation`):
A type written in source, such as `Map<String, dynamic>`, `void Function()` or `(int, String)`.
_Avoid_: type reference, type

**Use** (`Use`):
The position an expression's value fills in the code around it, ignoring parentheses and casts: a receiver, the operand of `!`, an argument of a call, or something else.
_Avoid_: usage, role, position, context
