# Changelog

## 0.1.0 (2026-11-18)


### ⚠ BREAKING CHANGES

* the JSON report's `schemaVersion` is now 2. Its summary counts are `total`, `error`, `warning` and `info` (formerly `violations`, `errors` and `warnings`). `Report.failing` is now `Report.reported`.
* vaixell.dart no longer exports BaselineFile, Engine, Package, PackageResolver, PackageDiscovery, PackageDir, ConfigLoader, ConfigResolver, GitRunner, RunGit, StartProcess, GitSourceTree, ClosableSourceTree, OpenGitSourceTree or FileSystemSourceTree. Check and WriteBaseline no longer accept engine, packageResolver, baselineFile, git or openGitSourceTree.
* Rule.check takes a DartFile; ParsedFile is removed.
* move the CLI into packages/vaixell_cli ([#20](https://github.com/marcossevilla/vaixell/issues/20))

### Features

* add --fatal-warnings and an info severity ([#71](https://github.com/marcossevilla/vaixell/issues/71)) ([b7adbfd](https://github.com/marcossevilla/vaixell/commit/b7adbfdc6b7fe7414b0c59b9eb17d28ae621b13a))
* add await-receiver rule ([#27](https://github.com/marcossevilla/vaixell/issues/27)) ([85a52b7](https://github.com/marcossevilla/vaixell/commit/85a52b7fd3cfa5c7cf4477a666803d88cf417630))
* AST-free rule authoring API ([#52](https://github.com/marcossevilla/vaixell/issues/52)) ([f5d1815](https://github.com/marcossevilla/vaixell/commit/f5d181536ec6507bf7edadbab2c581acc4387d3e))
* link every violation to its rule docs ([#70](https://github.com/marcossevilla/vaixell/issues/70)) ([39d064f](https://github.com/marcossevilla/vaixell/commit/39d064f9f4958071dfec8812ef1f8c625dded78c))


### Refactors

* move the CLI into packages/vaixell_cli ([#20](https://github.com/marcossevilla/vaixell/issues/20)) ([308772c](https://github.com/marcossevilla/vaixell/commit/308772c12ebdfe40a4c9aef5d787ea41079c45d5))
* tighten layers, fix crash paths and harden tests from architecture review ([#64](https://github.com/marcossevilla/vaixell/issues/64)) ([089bdcc](https://github.com/marcossevilla/vaixell/commit/089bdcc62603edc35917354eece540e21ffb155d))


### Docs

* move rules README to docs root ([#23](https://github.com/marcossevilla/vaixell/issues/23)) ([d4349b7](https://github.com/marcossevilla/vaixell/commit/d4349b7a9a5bbe0000f4bff975593e029ba1eaba))

## 0.1.0-dev.1

- Initial release.
