# Why Test Livebooks?

Livebook notebooks are a powerful way to share Elixir knowledge, but they share a common problem with all documentation: **they drift from reality**.

## The Documentation Drift Problem

When you write an example notebook, it works perfectly. But over time:

- **Dependency updates** break API calls shown in your notebook
- **Refactorings** rename or remove functions your examples use
- **Version mismatches** between your project and the published packages create inconsistencies

Your notebook says:

```elixir
Mix.install([{:my_lib, "~> 0.5"}])
MyLib.greet("world")
```

But `MyLib.greet/1` was renamed to `MyLib.hello/1` in v0.6. Now anyone following your notebook gets a confusing error.

## Testing Prevents Drift

`livebook_test` prevents this by running your notebooks as part of your test suite:

```bash
mix livebook.test
```

If any notebook fails, the test fails. Your CI pipeline catches problems before users do.

## What Gets Tested

- **Syntax**: Does the notebook parse correctly?
- **Compilation**: Does the code compile?
- **Execution**: Does the code run without errors?
- **Dependencies**: Can Mix.install resolve and fetch packages?

## What Doesn't Get Tested

- Visual output (charts, tables) - only code execution
- User interaction (inputs, forms) - these require a browser
- Side effects that require external services

## When to Test Livebooks

Test your Livebooks when they:

1. Appear in your project's repository
2. Are referenced in documentation
3. Serve as onboarding tutorials
4. Demonstrate API usage
5. Are used in CI/CD pipelines

## Next Steps

- [CI/CD for Livebook Notebooks](cicd_for_livebook_notebooks.md)
- [Local Dependency Testing](local_dependency_testing.md)
