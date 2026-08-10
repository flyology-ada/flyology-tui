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
- Themes are borrowed render-time values. Keep explicit style parameters as
  the low-level API, and do not retain a theme in component model state.
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

## Charm visual language

- Treat Charm as an interaction language, not a purple color scheme. Establish
  hierarchy first with composition, compact spacing, readable grouping, and a
  restrained number of borders; color enriches that structure but never
  substitutes for it.
- Give every persistent state a persistent non-color cue. Active tabs keep a
  fixed-width bracket shape, selected messages use a header plus structural
  rail, focused controls retain glyph or text cues, and docked/collapsed/
  floating panes expose distinct chrome. A brief color flash is not state.
- Keep ordinary content on the terminal's default foreground/background when
  possible. Use accent fills sparingly for small, high-value targets. Muted
  text must remain readable; reserve faint treatment for placeholders and
  disabled content.
- Preserve caller-owned body styling. Containers may paint their own header,
  rail, border, divider, or padding, but must not flood opaque, transparent, or
  heterogeneous child surfaces with selection or focus backgrounds.
- Derive component appearances from semantic palette roles. Keep explicit
  `Appearance` values as the low-level escape hatch and never branch on theme
  identity or retain a palette/theme in model state.
- Treat full skins as borrowed bundles of palette and structural chrome. A
  skin may change borders, shadows, tab edges, window marks, and dock cues, but
  must preserve immutable hit geometry, stable IDs, and the explicit
  Appearance/Theme overloads. Do not implement skins as model subclasses or
  identity tests inside component behavior.
- Design truecolor and gradients as progressive enhancement. Renderer profile
  adaptation must preserve distinct foreground/background identities and
  structural cues in ANSI-256, ANSI-16, monochrome, `NO_COLOR`, and unknown
  terminal backgrounds.
- Render and hit-test the same immutable geometry snapshot. Responsive zero-
  area controls are hidden and unfocusable; clipped chrome must not retain
  invisible modal or capture behavior.
- Kitchen-sink pages are reference interfaces, not packing tests. Center and
  bound the working area, align related cards, leave deliberate breathing
  room, and demonstrate keyboard/mouse parity plus responsive degradation.

## Workflow

- Run `git status --short --branch` before editing.
- Use `rg` for discovery and `apply_patch` for hand edits.
- Preserve unrelated changes.
- Run `./scripts/test.sh`, `alr show`, and `git diff --check` for normal
  changes. The script builds the library, runs the nested suite, and compiles
  both interactive examples.
- Run `./scripts/build-site.sh` for website, public API, component catalog, or
  website build changes. It must produce 34 component pages, 136 real Ada
  captures from dedicated component examples, and exact GNATdoc links. Follow
  `website/AGENTS.md` for authored site content.
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
