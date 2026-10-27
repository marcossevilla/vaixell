# vaixell

Checks architecture rules in Dart and Flutter repositories without resolving
types or running pub get.

This repository is a [pub workspace][workspace]. Its packages live in
`packages/`:

| Package                        | Description                    |
| ------------------------------ | ------------------------------ |
| [`vaixell`](packages/vaixell/) | The `vaixell` CLI and library. |

Run `dart pub get` at the root to resolve every package.

[workspace]: https://dart.dev/tools/pub/workspaces
