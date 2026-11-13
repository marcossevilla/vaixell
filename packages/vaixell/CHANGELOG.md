# Changelog

## 0.1.0 (2026-11-13)


### ⚠ BREAKING CHANGES

* vaixell.dart no longer exports BaselineFile, Engine, Package, PackageResolver, PackageDiscovery, PackageDir, ConfigLoader, ConfigResolver, GitRunner, RunGit, StartProcess, GitSourceTree, ClosableSourceTree, OpenGitSourceTree or FileSystemSourceTree. Check and WriteBaseline no longer accept engine, packageResolver, baselineFile, git or openGitSourceTree.
* PackageDiscovery.discover returns a List<PackageDir> instead of a List<String>, and nameOf(dir) is replaced by at(path).name.
* Config.recommended and ConfigLoader take a RuleSet instead of a List<RuleEntry>, and PackageResolver.fromTree throws the ArgumentError for a repeated or parse-error id when it's created instead of when a config loads.
* Rule.check takes a DartFile; ParsedFile is removed.
* move the CLI into packages/vaixell_cli ([#20](https://github.com/marcossevilla/vaixell/issues/20))
* add core Check and WriteBaseline callable classes ([#18](https://github.com/marcossevilla/vaixell/issues/18))
* `vaixell [options] [paths...]` is now `vaixell check [options] [paths...]`.

### Features

* add await-receiver rule ([#27](https://github.com/marcossevilla/vaixell/issues/27)) ([85a52b7](https://github.com/marcossevilla/vaixell/commit/85a52b7fd3cfa5c7cf4477a666803d88cf417630))
* add core Check and WriteBaseline callable classes ([#18](https://github.com/marcossevilla/vaixell/issues/18)) ([f3ae8e4](https://github.com/marcossevilla/vaixell/commit/f3ae8e4907a9192daea228601c3b0c009e3851ed))
* add generated-json rule ([#28](https://github.com/marcossevilla/vaixell/issues/28)) ([7665054](https://github.com/marcossevilla/vaixell/commit/766505469aa954d0ce7a8726f528b73fb2d80e11))
* add throwaway-instance rule ([#63](https://github.com/marcossevilla/vaixell/issues/63)) ([d99d83a](https://github.com/marcossevilla/vaixell/commit/d99d83ac698b89f7ad04bb81c166e9d13412de34))
* AST-free rule authoring API ([#52](https://github.com/marcossevilla/vaixell/issues/52)) ([f5d1815](https://github.com/marcossevilla/vaixell/commit/f5d181536ec6507bf7edadbab2c581acc4387d3e))
* scope extension-declaration to types the file declares ([#57](https://github.com/marcossevilla/vaixell/issues/57)) ([13f2dae](https://github.com/marcossevilla/vaixell/commit/13f2dae277b134b3c51cc23f30229cdc8e9af8e9))


### Bug Fixes

* advise a factory for generative fromJson constructors ([#54](https://github.com/marcossevilla/vaixell/issues/54)) ([2c039b0](https://github.com/marcossevilla/vaixell/commit/2c039b04376c12cbfaa18248e769064e2e1adf45))
* support glob workspace members ([#24](https://github.com/marcossevilla/vaixell/issues/24)) ([3075197](https://github.com/marcossevilla/vaixell/commit/30751975a7c35da519ebd58ff54a18a4b1af680a))


### Refactors

* break the rules ↔ engine ↔ config dependency cycle ([#16](https://github.com/marcossevilla/vaixell/issues/16)) ([97d4c2e](https://github.com/marcossevilla/vaixell/commit/97d4c2ebe22abcb176deb81d1cd405d233ce4930))
* build configs with Config.configure and a parsed _ConfigFile ([#60](https://github.com/marcossevilla/vaixell/issues/60)) ([b61205d](https://github.com/marcossevilla/vaixell/commit/b61205d5bded421615cd40c9f3069ae2fc0edbd6))
* check rule ids in RuleSet and build rules from RuleEntry ([#59](https://github.com/marcossevilla/vaixell/issues/59)) ([81383b9](https://github.com/marcossevilla/vaixell/commit/81383b9f730ae7d7c2b0afa6145864e648a5114b))
* find packages as PackageDirs that carry their name ([#61](https://github.com/marcossevilla/vaixell/issues/61)) ([1d85a1e](https://github.com/marcossevilla/vaixell/commit/1d85a1e987c3eb1c2ca56b086959bf36b00b59a9))
* move the CLI into packages/vaixell_cli ([#20](https://github.com/marcossevilla/vaixell/issues/20)) ([308772c](https://github.com/marcossevilla/vaixell/commit/308772c12ebdfe40a4c9aef5d787ea41079c45d5))
* parse, locate and sort through DartFile and Finding ([#62](https://github.com/marcossevilla/vaixell/issues/62)) ([ace9267](https://github.com/marcossevilla/vaixell/commit/ace926779a8af890c3dff3c76c420bc0bb432f79))
* restructure as a Very Good CLI workspace ([#2](https://github.com/marcossevilla/vaixell/issues/2)) ([c88e2f8](https://github.com/marcossevilla/vaixell/commit/c88e2f8a582dc98b47bf80083f8d4a01d4f9ef0f))
* tighten layers, fix crash paths and harden tests from architecture review ([#64](https://github.com/marcossevilla/vaixell/issues/64)) ([089bdcc](https://github.com/marcossevilla/vaixell/commit/089bdcc62603edc35917354eece540e21ffb155d))
* use package:git ([#17](https://github.com/marcossevilla/vaixell/issues/17)) ([c5ca502](https://github.com/marcossevilla/vaixell/commit/c5ca5027f24ddabfb286765408802e14725f598a)), closes [#15](https://github.com/marcossevilla/vaixell/issues/15)


### Docs

* move rules README to docs root ([#23](https://github.com/marcossevilla/vaixell/issues/23)) ([d4349b7](https://github.com/marcossevilla/vaixell/commit/d4349b7a9a5bbe0000f4bff975593e029ba1eaba))
* replace planning docs with a rule reference ([#5](https://github.com/marcossevilla/vaixell/issues/5)) ([0e3bd1e](https://github.com/marcossevilla/vaixell/commit/0e3bd1e5d5f3ea72976c2be86db29de7d062be56))

## 0.1.0-dev.1

- Initial release.
