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
- typed RGB, indexed, and ANSI colors plus text attributes;
- clipped cell surfaces, compositing, borders, padding, alignment, and joins;
- stateful cell diffing and declarative ANSI/DEC terminal modes;
- raw-mode POSIX lifecycle, resize observation, and interruptible waits;
- deterministic headless backend;
- spinner, progress, viewport, text input, list, help, and form components;
- an interactive counter example and nested behavioral test crate.

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

## Layers

- `Events`, `Application_Events`, `Transitions`, and `Programs` form the
  backend-free transition kernel.
- `Colors`, `Styles`, `Glyphs`, `Surfaces`, `Layouts`, and `Views` form the
  presentation model.
- `Input` and `Renderers` translate terminal bytes without owning a terminal.
- `Backends.POSIX` owns real terminal state; `Backends.Headless` is for tests.
- `Runners` supplies bounded input/effect orchestration.
- `Components.*` supplies reusable models and surface renderers.

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

The test action builds the library, runs the nested headless behavioral suite,
and compiles the POSIX counter example. To run the example in a terminal:

```sh
alr exec -- ./examples/bin/counter
alr exec -- ./examples/bin/kitchen_sink
```

The test suite is a nested Alire crate pinned to the parent library, keeping
test-only build state outside the published dependency set.

## Platform boundary

The released backend interface is deliberately expressed only in Flyology TUI
types. `Backends.POSIX` is implemented for macOS and Linux. Windows is preserved
as an architectural boundary but is not implemented. There is no dependency on
the Flyology runtime; a future adapter can replace waiting and command execution
without adding another model or update path.

## License

Flyology TUI is available under either the MIT License or the Apache License
2.0, at your option.
