# Executable Documentation

Livebook notebooks are a form of **executable documentation** — documentation that can be verified by running it.

## What is Executable Documentation?

Traditional documentation (README, wiki, blog posts) contains code snippets that are **copied and pasted** by readers. There's no guarantee the code still works.

Executable documentation is different: the code is **run automatically**, ensuring it always works.

## Livebook as Executable Documentation

Livebook's `.livemd` format is perfect for executable documentation because:

1. **Readable as plain text** — it's Markdown
2. **Version controllable** — diff-friendly text format
3. **Runnable** — Livebook can execute it directly
4. **Testable** — `livebook_test` can verify it in CI

## The livebook_test Approach

`livebook_test` treats notebooks as test artifacts:

1. **Discover** — Find all `.livemd` files in your project
2. **Export** — Convert them to standalone Elixir scripts
3. **Run** — Execute each script and check for errors
4. **Report** — Summarize which notebooks pass and fail

This creates a feedback loop: documentation that breaks is caught immediately.

## Best Practices

### Keep Notebooks Simple

Notebooks used as executable documentation should:

- Avoid long-running computations
- Avoid external service dependencies (or mock them)
- Use deterministic outputs
- Keep `Mix.install` dependencies minimal

### Structure for Testability

```markdown
# My Feature Guide

## Setup

```elixir
Mix.install([{:my_lib, "~> 0.5"}])
```

## Basic Usage

```elixir
MyLib.hello("world") |> IO.puts()
```

## Advanced Usage

```elixir
MyLib.configure(option: :value)
```
```

### Separate Interactive from Testable

Some Livebook features (inputs, smart cells, Kino widgets) are interactive and won't work in a headless test. Keep interactive elements in dedicated "demo" notebooks, separate from the "testable" documentation notebooks.

## Integration with Documentation Generators

`livebook_test` integrates with ExDoc. Include your notebooks in the `extras` section of `mix.exs`:

```elixir
docs: [
  extras: [
    "README.md",
    "examples/basic.livemd"
  ]
]
```

ExDoc will render the `.livemd` files as formatted documentation pages.

## Next Steps

- [Why Test Livebooks?](why_test_livebooks.md)
- [CI/CD for Livebook Notebooks](cicd_for_livebook_notebooks.md)
