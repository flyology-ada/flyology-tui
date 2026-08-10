# Flyology TUI

Flyology TUI is an experimental, typed terminal user-interface toolkit for
Ada. Its implementation follows the model/message/update/view architecture of
Elm and Bubble Tea, with Ada value types, in-place model updates, and structured
tasking.

The crate is independent from the Flyology runtime and builds with stock GNAT.
It currently supports interactive terminals on macOS and Linux. The backend
contract contains no POSIX types so a Windows console backend and an optional
Flyology-aware adapter can be added separately.

## What is implemented

- application-defined message, command, and model types;
- serial initialize/update/present dispatch with one model owner;
- one bounded command worker whose results re-enter as typed messages;
- incremental UTF-8, CSI, SGR mouse, focus, and bracketed-paste input parsing;
- typed mouse regions, terminal-to-local hit testing, and component interaction;
- terminal-oriented grapheme clusters and one- or two-cell glyph widths;
- typed RGB, indexed, and ANSI colors, negotiated color profiles, palette
  fallback, and text attributes;
- optional semantic themes and switchable full skins, including Charm and a
  Turbo Vision-inspired preset;
- clipped cell surfaces, compositing, borders, padding, alignment, and joins;
- stateful cell diffing and declarative ANSI/DEC terminal modes;
- raw-mode POSIX lifecycle, resize observation, and interruptible waits;
- deterministic headless backend;
- buttons, checks, radios, selectors, dropdowns, tabs, accordions, and
  application-composed menubars;
- tables, trees, breadcrumbs, lists, forms, viewports, and help;
- spinners, progress groups, indicators, sparklines, and scrollbars;
- split panes, jointly resizable panel groups, and movable/resizable windows;
- bounded text areas, syntax and semantically annotated Markdown
  editors/viewers, streaming text, and
  heterogeneous chat transcripts with caller-owned composers;
- sRGB- and linear-light-interpolated foreground/background gradients;
- interactive counter and responsive kitchen-sink examples plus a nested
  behavioral test crate.

Unicode handling covers the combining marks, variation selectors, emoji
modifiers, ZWJ sequences, and wide ranges commonly used by terminals. It is a
bounded terminal-width implementation, not a complete implementation of every
Unicode grapheme-boundary and locale-dependent ambiguous-width rule.

## Programming model

An application declares its own model, application messages, and command
values. Generic instances close those types without string tags or unchecked
payloads.

```ada
type Model is limited record
   Count : Integer := 0;
end record;

type Message is record
   Amount : Integer;
end record;

type Command is (Load, Save);

package Events is new Flyology_TUI.Application_Events (Message);
package Transitions is new Flyology_TUI.Transitions (Command);
```

`Initialize` and `Update` mutate the model on the runner's calling task. They
may request one command or quit through a transition. `Present` returns the
complete desired `View`; it does not write terminal bytes. A command executor
runs on the runner's worker task and returns an optional application message.

```ada
package Runtime is new Flyology_TUI.Runners
  (Events      => Events,
   Transitions => Transitions,
   Model_Type  => Model,
   Initialize  => Initialize,
   Update      => Update,
   Present     => Present,
   Execute     => Execute);

State    : Model;
Terminal : Flyology_TUI.Backends.POSIX.POSIX_Backend;

Runtime.Run (State, Terminal);
```

The model is deliberately mutable. The invariant is unidirectional ownership:
only the runner calls initialize, update, and present. Commands never receive a
live model reference.

That serial Elm-style owner remains canonical when an application uses other
implementation models. Pure renderers can stay stateless, synchronous retained
controllers can own bounded local state, and external tasks or actors can do
work concurrently. External workers may post only detached typed snapshots
into the serial inbox; they never own, mutate, or render live component UI
state.

## Layers

- `Events`, `Application_Events`, `Transitions`, and `Programs` form the
  backend-free transition kernel.
- `Colors`, `Styles`, `Themes`, `Glyphs`, `Surfaces`, `Layouts`, and `Views`
  form the presentation model.
- `Input` and `Renderers` translate terminal bytes without owning a terminal.
- `Backends.POSIX` owns real terminal state; `Backends.Headless` is for tests.
  Both can report the size sampled during `Open`, allowing the runner to
  deliver an initial resize before the first frame.
- `Runners` supplies bounded input/effect orchestration.
- `Components.*` supplies reusable models and surface renderers.

## Themes

Themes are ordinary values passed at render time. Components do not retain
them, and every explicit style-based `Render` signature remains available.

```ada
Palette : constant Flyology_TUI.Themes.Palette :=
  Flyology_TUI.Themes.Charm_Palette;
Visual : Flyology_TUI.Themes.Theme :=
  Flyology_TUI.Themes.To_Theme (Palette);

Visual.Primary := Flyology_TUI.Styles.With_Foreground
  (Visual.Primary, Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Cyan));

Frame := Input.Render (Visual);
```

`Themes.Default` leaves all roles at terminal defaults. `Themes.Charm` keeps
ordinary content at the terminal foreground and reserves its color for focus,
interaction, selection, and status. `Themes.Charm_Dark` and
`Themes.Charm_Light` provide explicit background-aware variants.

The additive `Palette` vocabulary distinguishes content, titles, interaction,
selection, and button states. Buttons, tabs, check boxes, radio groups,
selectors, and dropdowns accept it through `From_Palette`; their existing
`From_Theme`, theme-based `Render`, and explicit `Appearance` APIs remain
available. Applications can replace any role without creating a new component
type or storing presentation state in a model.

`Flyology_TUI.Skins` adds a borrowed structural layer above palettes. A skin
bundles desktop and semantic colors with panel/window border glyphs, clipped
hard shadows, tab markers, close marks, and dock chrome. The Charm default,
dark, and light skins retain the existing rounded visual language. The
Turbo Vision-inspired preset follows the later Borland vocabulary rather than
only borrowing its colors: a blue desktop and work windows, gray menu/status
bars and dialogs, cyan choice/list fields, blue edit fields, green commands,
centered border titles, single inactive and double active window frames,
leading close boxes, hard offset shadows, depressed buttons, textured
scrollbars, and red menu mnemonics. It is an inspired preset rather than an
API- or rendering-compatible clone.

Skin overloads are additive: the original explicit `Appearance`, `Theme`, and
render functions remain available. Models never retain the active skin.
Truecolor skin roles are adapted progressively through the renderer's
truecolor, ANSI-256, ANSI-16, and monochrome profiles while structural cues
remain unchanged.

See [docs/architecture.md](docs/architecture.md) for ownership and shutdown
details. [examples/src/counter.adb](examples/src/counter.adb) is the compact
starting point; [examples/src/kitchen_sink.adb](examples/src/kitchen_sink.adb)
composes every component, supports mouse focus/selection/scrolling, and uses a
repeating typed command for animation.

## Build and test

Alire 2.1 or newer is recommended. GNAT 13 through 16 is accepted by the crate.

```sh
alr build
alr test
```

The root test action builds the library, runs the nested behavioral suite, and
builds the nested examples crate. The nested crates can also be built directly:

```sh
cd tests && alr build
cd ../examples && alr build
```

To run an example in a terminal from the repository root:

```sh
alr exec -- ./examples/bin/counter
alr exec -- ./examples/bin/kitchen_sink
```

The kitchen sink accepts an explicit color policy when comparing terminal
fallbacks and an optional starting skin:

```sh
./examples/bin/kitchen_sink --color=auto
./examples/bin/kitchen_sink --color=mono
./examples/bin/kitchen_sink --color=ansi16
./examples/bin/kitchen_sink --color=ansi256
./examples/bin/kitchen_sink --color=truecolor
./examples/bin/kitchen_sink --skin=charm
./examples/bin/kitchen_sink --skin=dark
./examples/bin/kitchen_sink --skin=light
./examples/bin/kitchen_sink --skin=turbo --color=truecolor
```

Press `F6` in the kitchen sink to cycle skins without replacing any component
model or interaction state.

The examples and test suite are nested Alire crates pinned to the parent
library, keeping their build state outside the published dependency set. The
kitchen sink occupies the complete terminal, recomputes one layout snapshot on
every resize, and uses that snapshot for rendering, mouse routing, and cursor
projection. Its dedicated Markdown, Menus, Chat, Panels, Docking, Windows, and
Color pages use centered, page-specific bounds. Narrow terminals stack or
simplify regions instead of retaining a sparse wide arrangement. The Chat page
includes a persistent multiline composer and Send action. The Color page
identifies the active profile, compares palette fallbacks, and renders identical
stops with sRGB-channel and linear-light interpolation. The Docking page uses
the optional generic `Components.Dock_Workspaces` layer: stable pane IDs can
occupy one of four edge docks, collapse to a persistent rail, float as movable
and resizable windows, and dock again by command or by releasing a header at a
free edge.
Child surfaces and their input remain application-owned.

## Website and API documentation

The project guide, component catalog, and GNATdoc API are published at
[tui.flyology.org](https://tui.flyology.org/). The catalog contains one page
for every public component package. Each page includes generated previews for
all maintained skins.

Build the complete static site locally:

```sh
git submodule update --init
alr install gnatdoc_bin
./scripts/build-site.sh
```

The result is written to `build/site`. The build resolves authored API links
against GNATdoc's generated search index. It fails when a component page,
GNATdoc target, or skin preview is missing.

## Platform boundary

The released backend interface is deliberately expressed only in Flyology TUI
types. `Backends.POSIX` is implemented for macOS and Linux. Windows is preserved
as an architectural boundary but is not implemented. There is no dependency on
the Flyology runtime; a future adapter can replace waiting and command execution
without adding another model or update path.

## License

Flyology TUI is available under either the MIT License or the Apache License
2.0, at your option.
