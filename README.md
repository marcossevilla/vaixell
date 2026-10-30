# vaixell

Checks architecture rules in Dart and Flutter repositories without resolving
types or running pub get.

This repository is a [pub workspace][workspace]. Its packages live in
`packages/`:

| Package                                | Description                              |
| -------------------------------------- | ---------------------------------------- |
| [`vaixell`](packages/vaixell/)         | The `vaixell` library.                   |
| [`vaixell_cli`](packages/vaixell_cli/) | The `vaixell` CLI, built on the library. |

Run `dart pub get` at the root to resolve every package.

See [`docs/rules`](docs/rules/) for the rules vaixell supports and how to
configure them.

## Releasing

[release-please][release-please] versions `vaixell` and `vaixell_cli`
independently. Merging a release PR tags the release as `vaixell-v<version>` or
`vaixell_cli-v<version>`, and the `pub_publish` workflow publishes the matching
package to pub.dev.

When `vaixell_cli` needs a new `vaixell` release, the PR that needs it bumps the
`vaixell` constraint in `packages/vaixell_cli/pubspec.yaml`.

Before the first automated release, set up each package by hand:

1. Publish the first version manually: run `dart pub publish` in
   `packages/vaixell`, then in `packages/vaixell_cli`.
2. On pub.dev, open each package's **Admin** tab and enable **Automated
   publishing** from GitHub Actions:
   - Repository: `marcossevilla/vaixell`
   - Tag pattern: `vaixell-v{{version}}` for `vaixell`, and
     `vaixell_cli-v{{version}}` for `vaixell_cli`
   - Require the `pub.dev` GitHub Actions environment.

[release-please]: https://github.com/googleapis/release-please
[workspace]: https://dart.dev/tools/pub/workspaces
