# Flyology TUI agent guide

## Identity

- The project is **Flyology TUI**. The Alire crate is `flyology_tui`, the Ada
  root package is `Flyology_TUI`, and the repository is `flyology-tui`.
- The crate is independent from the Flyology runtime. Keep Flyology integration
  in an adapter so stock-GNAT consumers do not prepare a custom RTS.
- Write modest, factual prose. The project is experimental.

## Architecture

- Preserve one model owner and serial event dispatch.
- `Update` may mutate the model in place but must not perform blocking external
  I/O. Commands carry effects and return results as messages.
- Keep terminal events, application messages, commands, and backend state
  strongly typed. Do not replace them with unchecked addresses or string tags.
- `Present` declares a complete view and performs no I/O.
- Styled surfaces own rectangular cell values. A two-column glyph owns its
  continuation cell; overwriting either half must clear the old span.
- Input parsing is incremental and bounded. Preserve incomplete UTF-8, escape,
  and bracketed-paste sequences across reads without exposing raw control
  strings to applications.
- Mouse events use terminal-cell coordinates until the application routes them
  through `Mouse.Region`; interactive components consume localized coordinates.
- The stock runner has one bounded command worker. Shutdown interrupts input,
  completes accepted command work, joins both workers, and restores the
  backend before returning.
- Terminal state belongs to a backend. `Close` must restore every changed mode
  and remain safe after partial initialization.
- Keep the backend interface free of POSIX types. macOS/Linux are first; the
  same public boundary is reserved for Windows.
- Prefer Ada for implementation. Retain C only for ABI facts or mechanisms that
  cannot be expressed reliably through direct Ada imports, and keep policy in
  Ada.
- `src/native/flyology_tui_posix.c` is limited to termios, winsize, pollfd, and
  descriptor-flag ABI mechanisms. Parsing, rendering, timeout policy, retries,
  and cleanup order remain in Ada.

## Workflow

- Run `git status --short --branch` before editing.
- Use `rg` for discovery and `apply_patch` for hand edits.
- Preserve unrelated changes.
- Run `./scripts/test.sh`, `alr show`, and `git diff --check` for normal
  changes. The script builds the library, runs the nested suite, and compiles
  both interactive examples.
- Tests live in the nested `tests` crate and depend on the parent through a path
  pin.
- Do not commit generated `alire`, `config`, `obj`, `lib`, or test binaries.

## Commits

Use focused Problem/Solution commit messages:

```text
Problem: <present-tense problem statement>

<Impact and repository context.>

Solution: <one-line solution statement>

<What changed and why.>
```
