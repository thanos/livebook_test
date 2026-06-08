# Contributing to livebook_test

Thank you for your interest in contributing! This project welcomes contributions
of all kinds: bug reports, feature requests, documentation improvements, and
code changes.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/livebook_test.git`
3. Install dependencies: `mix deps.get`
4. Run tests: `mix test --exclude livebook_integration`
5. Run Livebook tests: `mix livebook.test`

## Development Workflow

1. Create a branch for your change
2. Make your changes
3. Ensure all checks pass:

    ```bash
    mix format --check-formatted
    mix compile --warnings-as-errors
    mix test --exclude livebook_integration
    mix credo
    ```

4. Commit with a clear message
5. Push and open a pull request

## Code Style

- Follow the existing code style
- Add `@moduledoc` to all public modules
- Add `@doc` with examples to all public functions
- Add `@spec` typespecs to all public functions
- Run `mix format` before committing

## Reporting Issues

When reporting bugs, please include:

- Elixir and OTP versions
- Livebook version
- Steps to reproduce
- Expected vs actual behavior

## Pull Requests

- Keep PRs focused on a single change
- Include tests for new functionality
- Update documentation when changing behavior
- Ensure CI passes on all checks

## License

By contributing, you agree that your contributions will be licensed under the
MIT License.
