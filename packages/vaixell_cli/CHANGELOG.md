# Changelog

## 0.1.0 (2026-11-13)


### ⚠ BREAKING CHANGES

* vaixell.dart no longer exports BaselineFile, Engine, Package, PackageResolver, PackageDiscovery, PackageDir, ConfigLoader, ConfigResolver, GitRunner, RunGit, StartProcess, GitSourceTree, ClosableSourceTree, OpenGitSourceTree or FileSystemSourceTree. Check and WriteBaseline no longer accept engine, packageResolver, baselineFile, git or openGitSourceTree.
* Rule.check takes a DartFile; ParsedFile is removed.
* move the CLI into packages/vaixell_cli ([#20](https://github.com/marcossevilla/vaixell/issues/20))

### Features

* add await-receiver rule ([#27](https://github.com/marcossevilla/vaixell/issues/27)) ([85a52b7](https://github.com/marcossevilla/vaixell/commit/85a52b7fd3cfa5c7cf4477a666803d88cf417630))
* AST-free rule authoring API ([#52](https://github.com/marcossevilla/vaixell/issues/52)) ([f5d1815](https://github.com/marcossevilla/vaixell/commit/f5d181536ec6507bf7edadbab2c581acc4387d3e))


### Refactors

* move the CLI into packages/vaixell_cli ([#20](https://github.com/marcossevilla/vaixell/issues/20)) ([308772c](https://github.com/marcossevilla/vaixell/commit/308772c12ebdfe40a4c9aef5d787ea41079c45d5))
* tighten layers, fix crash paths and harden tests from architecture review ([#64](https://github.com/marcossevilla/vaixell/issues/64)) ([089bdcc](https://github.com/marcossevilla/vaixell/commit/089bdcc62603edc35917354eece540e21ffb155d))


### Docs

* move rules README to docs root ([#23](https://github.com/marcossevilla/vaixell/issues/23)) ([d4349b7](https://github.com/marcossevilla/vaixell/commit/d4349b7a9a5bbe0000f4bff975593e029ba1eaba))

## 0.1.0-dev.1

- Initial release.
