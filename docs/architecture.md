# Architecture

## Core data flow

Flyology TUI uses Elm semantics with Ada mechanics:

1. One owner serially dispatches events to the application model.
2. `Update` mutates that model in place and may declare one typed command.
3. A runner executes commands outside the update call.
4. Command results return as typed application messages.
5. `Present` describes the complete desired view without performing I/O.
6. A backend reconciles that view with terminal state and restores all modes on
   close.

A command value may encode a batch or sequence. This keeps the transition
record bounded and definite while allowing applications and future component
packages to define richer effect policies.

## Package boundaries

- `Flyology_TUI.Events` defines terminal input independently from any operating
  system decoder.
- `Flyology_TUI.Application_Events` combines terminal input with one
  application-defined message type.
- `Flyology_TUI.Transitions` records typed command and quit requests.
- `Flyology_TUI.Programs` invokes application transition and presentation
  callbacks. It performs no I/O and owns no task.
- `Flyology_TUI.Views` declares content and terminal modes.
- `Flyology_TUI.Backends` separates program semantics from terminal I/O.

## Runtime independence

The core crate does not depend on Flyology. A mandatory dependency would make a
custom GNAT runtime part of every TUI application's build even when native Ada
tasking is sufficient.

The backend interface leaves room for a separate adapter that waits through
Flyology I/O and runs command executors as lightweight tasks. That adapter must
not introduce a second application model or a second update path.

## Platform plan

The first terminal backend targets macOS and Linux and will use direct POSIX
terminal control, a wake descriptor, and an ANSI/DEC input parser. The public
backend interface contains no POSIX descriptor or `termios` type. A future
Windows console backend can therefore implement the same lifecycle, input, and
rendering operations without changing applications.

## Invariants

- Only the event-loop owner mutates or presents the model.
- `Initialize`, `Update`, and `Present` do not block on external I/O.
- A command never receives a live model reference.
- Every dispatch begins with an empty transition; effects cannot leak from a
  prior event.
- Backend `Close` is idempotent and safe after partial initialization.
- Backend `Interrupt` is task-safe and wakes a blocked `Next_Event` promptly.
- Terminal bytes and capability replies are untrusted, bounded input.
- The renderer will compare typed cells, not application-provided cursor
  commands.
