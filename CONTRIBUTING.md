# Contributing

Thanks for contributing to the DDEV Claude Code add-on!

## Prerequisites

- [DDEV](https://ddev.com/) installed and working (the tests create and start a real DDEV project).
- [Bats](https://bats-core.readthedocs.io/) plus the `bats-assert`, `bats-file`, and `bats-support` helper libraries.

## Installing Bats

### macOS (Homebrew)

```bash
brew install bats-core bats-assert bats-file bats-support
```

The tests automatically pick these up from your Homebrew prefix.

### Linux

Install `bats-core` via your package manager (or [from source](https://bats-core.readthedocs.io/en/stable/installation.html)), then install the helper libraries:

```bash
# Debian/Ubuntu
sudo apt-get install bats

# Helper libraries (clone into a directory on your BATS_LIB_PATH, e.g. /usr/lib/bats)
sudo git clone https://github.com/bats-core/bats-assert  /usr/lib/bats/bats-assert
sudo git clone https://github.com/bats-core/bats-file    /usr/lib/bats/bats-file
sudo git clone https://github.com/bats-core/bats-support /usr/lib/bats/bats-support
```

The tests look for the helper libraries on `BATS_LIB_PATH`, which defaults to include
`/usr/lib/bats` and `/usr/local/lib/bats`. If you install them elsewhere, export
`BATS_LIB_PATH` to point at that location:

```bash
export BATS_LIB_PATH="/path/to/your/bats/libraries"
```

## Running the tests

From the add-on root directory:

```bash
bats ./tests/test.bats --filter-tags '!release'
```

The `install from directory` test installs the add-on from your local working copy, so it
reflects your current changes. The `install from release` test installs the published
release from GitHub, so it's only meaningful in CI — the `--filter-tags '!release'` above
excludes it while developing locally. (CI runs it on the daily schedule; see below.)

For more verbose output when debugging a failure:

```bash
bats ./tests/test.bats --filter-tags '!release' --show-output-of-passing-tests --verbose-run --print-output-on-failure
```

## Continuous integration

The same tests run automatically in GitHub Actions (see
[`.github/workflows/tests.yml`](.github/workflows/tests.yml)) on pull requests and pushes
to `main`, against both the `stable` and `HEAD` versions of DDEV.

There is also a daily scheduled run. On pull requests and pushes the `install from
release` test is skipped (via its `release` tag), so only `install from directory` runs.
The scheduled run executes the full suite — including `install from release` — which acts
as a regression check that the latest published release still installs and works against
current DDEV. This is why a `HEAD` failure can show up on the schedule before it appears
on any pull request.