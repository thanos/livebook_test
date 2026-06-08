# livebook_test

> **mix test for Livebooks** — Keep your Livebook examples honest.

`livebook_test` brings `mix test`-style workflows to Livebook notebooks. It discovers `.livemd` files, converts them to executable Elixir scripts, runs them, and reports failures — locally and in CI/CD.

[![CI](https://github.com/thanos/livebook_test/actions/workflows/ci.yml/badge.svg)](https://github.com/thanos/livebook_test/actions/workflows/ci.yml)
[![Hex version](https://img.shields.io/hexpm/v/livebook_test.svg)](https://hex.pm/packages/livebook_test)
[![Hex docs](https://img.shields.io/badge/docs-hexdocs.pm-blue)](https://hexdocs.pm/livebook_test)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Coverage Status](https://coveralls.io/repos/github/thanos/livebook_test/badge.svg?branch=main)](https://coveralls.io/github/thanos/livebook_test?branch=main)

## Why?

Livebook notebooks are great for examples, tutorials, and interactive documentation. But they drift:

- A dependency update breaks your example notebook
- A refactoring breaks the API shown in a tutorial
- Published notebooks reference old package versions

**livebook_test** catches these problems before your users do.

## Installation

Add to your Mix project:

```elixir
def deps do
  [
    {:livebook_test, "~> 0.1.0", only: [:dev, :test], runtime: false}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Quick Start

```bash
# Run all discovered notebooks
mix livebook.test

# Run with verbose output
mix livebook.test --verbose

# Test against local checkout instead of Hex
mix livebook.test --mode local

# Run a specific notebook (including a broken one to verify failure detection)
mix livebook.test --path examples/broken.livemd
```

### Example Notebooks

| Notebook | Description |
|----------|-------------|
| `examples/basic.livemd` | Simple arithmetic and IO — passes |
| `examples/mix_install.livemd` | Uses `Mix.install` with Jason — passes |
| `examples/broken.livemd` | Intentionally failing cells — use to verify failure reporting |

## Configuration

Configure in `config/config.exs`:

```elixir
config :livebook_test,
  paths: ["examples/basic.livemd", "examples/mix_install.livemd"],
  dependency_mode: :remote,
  timeout: 60_000,
  local_deps: [],
  verbose: false
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `paths` | `["examples/basic.livemd", "examples/mix_install.livemd"]` | Glob patterns or explicit paths for notebook discovery |
| `dependency_mode` | `:remote` | `:remote` leaves deps unchanged, `:local` rewrites to path deps |
| `timeout` | `60_000` | Per-notebook timeout in milliseconds |
| `local_deps` | `[]` | Map of dependency names to local paths |
| `verbose` | `false` | Show per-notebook details |

## Local Dependency Testing

The killer feature: notebooks that use `Mix.install` can be automatically patched to use your local checkout.

### Problem

Your example notebook says:

```elixir
Mix.install([
  {:my_lib, "~> 0.5"}
])
```

But you want CI to test against the current checkout, not the published Hex version.

### Solution

```elixir
# config/config.exs
config :livebook_test,
  dependency_mode: :local,
  local_deps: [
    my_lib: "."
  ]
```

Now `{:my_lib, "~> 0.5"}` becomes `{:my_lib, path: "."}`.

Or via CLI:

```bash
mix livebook.test --mode local
```

## CI/CD Integration

Add to your GitHub Actions workflow:

```yaml
- name: Test Livebooks
  run: mix livebook.test
```

With local deps:

```yaml
- name: Test Livebooks (local)
  run: mix livebook.test --mode local
```

The task exits with code `0` on success and `1` on failure, perfect for CI gates.

## CLI Options

```
mix livebook.test [options]

Options:
  --path PATTERN   Glob pattern for discovery (repeatable)
  --mode MODE      Dependency mode: local or remote
  --timeout SECS   Per-notebook timeout in seconds
  --verbose        Show per-notebook details
```

## Programmatic API

```elixir
# Run with defaults
LivebookTest.run()

# Run with options
LivebookTest.run(paths: ["examples/**/*.livemd"], mode: :local, timeout: 120_000)

# Run and print report, returns exit code
LivebookTest.run_and_report(verbose: true)
```

## Pipeline

Notebooks flow through a pipeline:

1. **Discovery** — Find `.livemd` files via glob patterns
2. **Export** — Convert to `.exs` scripts using `Livebook.live_markdown_to_elixir/1`
3. **Patch** — Optionally rewrite `Mix.install` deps to local paths
4. **Run** — Execute each script as an isolated subprocess
5. **Report** — Summarize results with pass/fail counts and timing

## Example Output

```
3 notebooks
3 passed
0 failed
Total time: 2.1s

All notebooks passed! ✅
```

With failures:

```
3 notebooks
2 passed
1 failed
Total time: 5.3s

Failed notebooks:
--------------------

  examples/failing.livemd
  exit: 1
    RuntimeError: Intentional failure for testing
```

## Architecture

| Module | Responsibility |
|--------|---------------|
| `LivebookTest` | Public entry point, orchestration |
| `LivebookTest.Config` | Configuration resolution |
| `LivebookTest.Discovery` | Notebook file discovery |
| `LivebookTest.Exporter` | `.livemd` → `.exs` conversion |
| `LivebookTest.DependencyPatcher` | Mix.install dependency rewriting |
| `LivebookTest.Runner` | Script execution and result collection |
| `LivebookTest.Report` | Summary formatting and exit codes |

## Roadmap

| Version | Feature |
|---------|---------|
| v0.2.0 | Snapshot testing |
| v0.3.0 | Parallel execution |
| v0.4.0 | JUnit output |
| v0.5.0 | GitHub annotations |
| v0.6.0 | Notebook metadata and tags |
| v0.7.0 | Coverage reporting |
| v0.8.0 | HTML reports |
| v0.9.0 | Distributed notebook execution |
| v1.0.0 | Stable public API |

## License

MIT
