# Changelog

## 0.1.0 (2026-10-30)


### ⚠ BREAKING CHANGES

* move the CLI into packages/vaixell_cli ([#20](https://github.com/marcossevilla/vaixell/issues/20))
* add core Check and WriteBaseline callable classes ([#18](https://github.com/marcossevilla/vaixell/issues/18))
* `vaixell [options] [paths...]` is now `vaixell check [options] [paths...]`.

### Features

* add core Check and WriteBaseline callable classes ([#18](https://github.com/marcossevilla/vaixell/issues/18)) ([f3ae8e4](https://github.com/marcossevilla/vaixell/commit/f3ae8e4907a9192daea228601c3b0c009e3851ed))


### Bug Fixes

* support glob workspace members ([#24](https://github.com/marcossevilla/vaixell/issues/24)) ([3075197](https://github.com/marcossevilla/vaixell/commit/30751975a7c35da519ebd58ff54a18a4b1af680a))


### Refactors

* break the rules ↔ engine ↔ config dependency cycle ([#16](https://github.com/marcossevilla/vaixell/issues/16)) ([97d4c2e](https://github.com/marcossevilla/vaixell/commit/97d4c2ebe22abcb176deb81d1cd405d233ce4930))
* move the CLI into packages/vaixell_cli ([#20](https://github.com/marcossevilla/vaixell/issues/20)) ([308772c](https://github.com/marcossevilla/vaixell/commit/308772c12ebdfe40a4c9aef5d787ea41079c45d5))
* restructure as a Very Good CLI workspace ([#2](https://github.com/marcossevilla/vaixell/issues/2)) ([c88e2f8](https://github.com/marcossevilla/vaixell/commit/c88e2f8a582dc98b47bf80083f8d4a01d4f9ef0f))
* use package:git ([#17](https://github.com/marcossevilla/vaixell/issues/17)) ([c5ca502](https://github.com/marcossevilla/vaixell/commit/c5ca5027f24ddabfb286765408802e14725f598a)), closes [#15](https://github.com/marcossevilla/vaixell/issues/15)


### Docs

* move rules README to docs root ([#23](https://github.com/marcossevilla/vaixell/issues/23)) ([d4349b7](https://github.com/marcossevilla/vaixell/commit/d4349b7a9a5bbe0000f4bff975593e029ba1eaba))
* replace planning docs with a rule reference ([#5](https://github.com/marcossevilla/vaixell/issues/5)) ([0e3bd1e](https://github.com/marcossevilla/vaixell/commit/0e3bd1e5d5f3ea72976c2be86db29de7d062be56))

## 0.1.0-dev.1

- Initial release.
