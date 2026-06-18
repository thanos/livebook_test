# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-06-17

### Added

- `LivebookTest.Preflight` — runtime checks for Elixir, OTP, and Livebook compatibility
- Path dependency patching in `--mode local` (rewrites `path:` and `Path.join(__DIR__, ...)` deps to absolute paths)
- Kino limitations guide (`docs/guides/kino_limitations.md`)
- CI matrix runs `mix livebook.test` across supported Elixir/OTP versions
- Documented supported versions: Elixir `~> 1.18`, OTP 26/27/28, Livebook `~> 0.19.0`

### Changed

- `DependencyPatcher` now expands local paths to absolute paths for stable CI execution
- Export failures include troubleshooting hints when Livebook is unavailable or incompatible
- `mix livebook.test` runs preflight checks before notebook discovery
- `LivebookTest.Runner` results include `harness_error` to distinguish runner failures from notebook exit codes
- Doctests wired up across public modules; local-mode patching verified end-to-end in tests and CI
- Documentation and output tone cleaned up (install pin, ExDoc wording, plain-ASCII punctuation, no emoji in reports)

### Fixed

- `run/1` and `run_and_report/1` now honor `:runner` and `:preflight` options
- Removed dead `Config.from_cli/1` CLI parsing duplicate
- CI local-mode job runs `livebooks/local_dep.livemd` with `local_deps: [jason: "."]`
- Discovery exclude behavior documented in tests (exact path identity after wildcard expansion)
- Verbose patch-write failure test uses injectable `:patch_writer` instead of filesystem permissions

## [0.1.0] - 2026-06-08

### Added

- Initial release of `livebook_test`
- `mix livebook.test` Mix task with `--path`, `--exclude`, `--mode`, `--timeout`, `--verbose` options
- Notebook discovery via glob patterns (`LivebookTest.Discovery`)
- Notebook export using `Livebook.live_markdown_to_elixir/1` (`LivebookTest.Exporter`)
- Dependency patching for local testing (`LivebookTest.DependencyPatcher`)
  - Remote mode: leave `Mix.install` deps unchanged
  - Local mode: rewrite Hex deps to local path deps
- Subprocess-based script execution (`LivebookTest.Runner`)
- Summary reporting with pass/fail counts and timing (`LivebookTest.Report`)
- Configuration via application environment and CLI options (`LivebookTest.Config`)
- Programmatic API (`LivebookTest.run/1`, `LivebookTest.run_and_report/1`)
- CI/CD-friendly exit codes (0 = pass, 1 = fail)
- Example notebooks in `examples/` directory
- GitHub Actions CI workflow
- Full ExUnit test suite

[0.1.1]: https://github.com/thanos/livebook_test/releases/tag/v0.1.1
[0.1.0]: https://github.com/thanos/livebook_test/releases/tag/v0.1.0
