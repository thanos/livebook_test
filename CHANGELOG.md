# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-08

### Added

- Initial release of `livebook_test`
- `mix livebook.test` Mix task with `--path`, `--mode`, `--timeout`, `--verbose` options
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

[0.1.0]: https://github.com/thanos/livebook_test/releases/tag/v0.1.0
