## vaixell_cli

![coverage][coverage_badge]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

The `vaixell` command-line interface. It checks architecture rules in Dart and
Flutter repositories, built on the [`vaixell`][vaixell_link] library.

---

## Getting Started 🚀

If the CLI application is available on [pub](https://pub.dev), activate globally via:

```sh
dart pub global activate vaixell_cli
```

This installs the `vaixell` executable.

Or locally via:

```sh
dart pub global activate --source=path <path to this package>
```

## Usage

```sh
# Check the packages in the current directory: the workspace members,
# packages/* and pkgs/*
$ vaixell check

# Check specific package directories
$ vaixell check packages/a packages/b

# Report only violations added or fixed since the merge-base with main
$ vaixell check --git-diff=main

# Write a baseline, then suppress the violations it lists
$ vaixell check --write-baseline=vaixell_baseline.json
$ vaixell check --baseline=vaixell_baseline.json

# Machine-readable output: JSON, or GitHub Actions annotations
$ vaixell check --format=json
$ vaixell check --format=github

# Update the CLI
$ vaixell update

# Show CLI version
$ vaixell --version

# Show usage help
$ vaixell --help
```

See the [rules documentation][rules_link] for every supported rule and how to
configure them.

## Running Tests with coverage 🧪

To run all unit tests use the following command:

```sh
$ dart pub global activate coverage 1.15.0
$ dart test --coverage=coverage
$ dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
```

To view the generated coverage report you can use [lcov](https://github.com/linux-test-project/lcov)
.

```sh
# Generate Coverage Report
$ genhtml coverage/lcov.info -o coverage/

# Open Coverage Report
$ open coverage/index.html
```

---

[coverage_badge]: coverage_badge.svg
[rules_link]: https://github.com/marcossevilla/vaixell/tree/main/docs
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[vaixell_link]: https://github.com/marcossevilla/vaixell/tree/main/packages/vaixell
