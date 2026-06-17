# Local Dependency Testing

The most powerful feature of `livebook_test` is the ability to test notebooks against your **current codebase** instead of published packages.

## The Problem

Example notebooks in your repository typically reference your published Hex package:

```elixir
Mix.install([
  {:my_lib, "~> 0.5"}
])
```

This works for end users, but creates a problem in CI: the notebook tests the **published** version of your code, not the **current** branch. Bugs in the current branch won't be caught by the notebook.

## The Solution

`livebook_test` can automatically rewrite `Mix.install` dependencies to point to local paths:

```bash
mix livebook.test --mode local
```

This transforms:

```elixir
Mix.install([{:my_lib, "~> 0.5"}])
```

into:

```elixir
Mix.install([{:my_lib, path: "/abs/path/to/checkout"}])
```

Path-style dependencies are rewritten the same way:

```elixir
# Before
Mix.install([{:my_lib, path: Path.join(__DIR__, "..")}])

# After (local mode, when my_lib is in local_deps)
Mix.install([{:my_lib, path: "/abs/path/to/checkout"}])
```

Paths are expanded to absolute paths so CI runs behave consistently regardless of working directory.

## Configuration

### Via CLI

```bash
mix livebook.test --mode local
```

### Via Application Config

```elixir
# config/config.exs
config :livebook_test,
  dependency_mode: :local,
  local_deps: [
    my_lib: ".",
    other_lib: "../other_lib"
  ]
```

### Programmatic

```elixir
LivebookTest.run(mode: :local, local_deps: [my_lib: "."])
```

## Multiple Dependencies

When your notebook depends on multiple packages from your organization:

```elixir
Mix.install([
  {:ex_arrow, "~> 0.5"},
  {:ex_datalog, "~> 1.0"}
])
```

Configure each:

```elixir
config :livebook_test,
  dependency_mode: :local,
  local_deps: [
    ex_arrow: ".",
    ex_datalog: "../ex_datalog"
  ]
```

Both dependencies will be rewritten to use local paths.

## How It Works

The `DependencyPatcher` module uses regex-based replacement on the **exported Elixir script** (not the `.livemd` source). This means:

1. Your `.livemd` files remain unchanged - they still reference Hex versions
2. Only the temporary `.exs` scripts used for testing are patched
3. After the test run, the temporary scripts are deleted automatically

## When to Use Remote vs Local

| Mode | When to Use |
|------|------------|
| `:remote` | Verifying notebooks work with published packages |
| `:local` | Testing notebooks against current checkout in CI |

A good CI strategy: run both modes in separate jobs.

## Next Steps

- [CI/CD for Livebook Notebooks](cicd_for_livebook_notebooks.md)
- [Executable Documentation](executable_documentation.md)
