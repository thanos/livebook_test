# Kino and Interactive Notebook Limitations

`livebook_test` exports notebooks to standalone Elixir scripts and runs them headlessly. Some Livebook features do not translate cleanly to this model.

## What exports cleanly

Most standard Elixir cells export and run without changes:

- `Mix.install/2` dependency setup
- Plain Elixir code and `IO.puts/1`
- Data processing and assertions
- Libraries without interactive UI (Jason, NimbleCSV, etc.)

## What does not export cleanly

### Kino widgets and outputs

Kino provides interactive outputs: charts, tables, inputs, smart cells, and live updates. These depend on Livebook's runtime UI and often:

- Reference Kino-specific APIs that assume a connected frontend
- Block on user input (`Kino.input/2`, forms, file pickers)
- Spawn processes tied to the Livebook session lifecycle

When exported via `Livebook.live_markdown_to_elixir/1`, Kino-heavy cells may fail at compile time, raise at runtime, or hang waiting for input.

### Smart cells

Smart cells generate Elixir from a UI configuration. The exported script contains the generated code, but cells that require re-configuration or runtime UI will not work headlessly.

### Frame and control widgets

`Kino.Frame`, sliders, and similar controls expect a browser session. In CI there is no browser.

## Recommended strategies

### 1. Separate demo notebooks from test notebooks

Keep interactive Kino demos in notebooks excluded from CI:

```elixir
config :livebook_test,
  exclude: ["**/demos/**", "**/broken/**/*.livemd"]
```

### 2. Test the logic, not the widget

Extract core logic into plain Elixir cells or a library module, then test those cells:

```elixir
# Testable cell
result = MyLib.compute([1, 2, 3])
IO.puts(result)
```

### 3. Use remote mode for Kino-free verification

Run `mix livebook.test --mode remote` on notebooks that only use Hex dependencies and avoid Kino.

### 4. Future: skip Kino cells

A `--skip-kino` flag is planned for a future release. Until then, structure notebooks so Kino cells are optional or isolated.

## Diagnosing Kino-related failures

| Symptom | Likely cause |
|---------|--------------|
| `undefined function Kino.*` | Kino not installed in exported script |
| Hang until timeout | Cell waiting for user input |
| Compile error in exported `.exs` | Smart cell or Kino macro not exportable |
| Empty or missing output | Kino render calls with no headless fallback |

Enable verbose output to inspect per-notebook stderr:

```bash
mix livebook.test --verbose
```

## Related reading

- [Why Test Livebooks?](why_test_livebooks.md)
- [Executable Documentation](executable_documentation.md)
- [CI/CD for Livebook Notebooks](cicd_for_livebook_notebooks.md)
