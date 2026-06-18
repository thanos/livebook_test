# CI/CD for Livebook Notebooks

Running Livebook tests in CI ensures your notebooks stay working as your codebase evolves.

## GitHub Actions

Add a step to your workflow:

```yaml
- name: Test Livebooks
  run: mix livebook.test
```

Full example:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.18"
          otp-version: 27

      - run: mix deps.get

      - run: mix test

      - run: mix livebook.test
```

## Exit Codes

`mix livebook.test` exits with:

- **0** - all notebooks passed
- **1** - one or more notebooks failed
- **2** - no notebooks discovered (check your paths and exclude patterns)

This matches standard CI expectations.

## Timeout Configuration

Notebooks that call `Mix.install` may need more time in CI (especially on first runs when packages must be downloaded):

```bash
mix livebook.test --timeout 180
```

Or in config:

```elixir
config :livebook_test, timeout: 180_000
```

## Caching Mix.install Dependencies

`Mix.install` downloads and compiles packages to a cache directory on first use. The default location varies by platform but can be controlled with the `MIX_INSTALL_DIR` environment variable. In CI, you can cache this directory to speed up runs:

```yaml
- name: Cache Mix.install
  uses: actions/cache@v4
  with:
    path: ~/.cache/mix_install
    key: livebook-deps-${{ hashFiles('**/*.livemd') }}
  env:
    MIX_INSTALL_DIR: ~/.cache/mix_install

- name: Test Livebooks
  run: mix livebook.test
  env:
    MIX_INSTALL_DIR: ~/.cache/mix_install
```

See the [Mix.install documentation](https://hexdocs.pm/mix/Mix.html#install/2) for details on cache configuration.

## Selective Testing

Use `--path` to test specific notebooks:

```bash
mix livebook.test --path examples/basic.livemd
```

This is useful for testing only changed notebooks in a PR.

## Next Steps

- [Local Dependency Testing](local_dependency_testing.md)
- [Executable Documentation](executable_documentation.md)
