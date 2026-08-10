# Architecture

## Data flow

Flyology TUI uses Elm semantics with Ada mechanics:

1. A runner owns the application model on its calling task.
2. Terminal events and command results enter one bounded inbox.
3. `Update` mutates the model serially and may declare one typed command.
4. A single command worker executes commands outside `Update`.
5. Command results return as typed application messages.
6. `Present` constructs the complete desired view without performing I/O.
7. The backend reconciles that view with terminal state.

One command value may encode application-defined batching or sequencing. The
runner applies bounded backpressure instead of creating a task for every
effect. On shutdown it stops accepting new messages, drains accepted command
work, interrupts terminal input, waits for both workers, and closes the backend.
An unexpected worker exception becomes `Runner_Error` after orderly cleanup.

`Programs` remains a task-free kernel for applications that want to supply a
different orchestration policy.

The serial Elm-style owner is the canonical state model, not a requirement
that every reusable unit have the same internal shape. Pure renderers may
remain stateless, and synchronous retained controllers may own their bounded
local interaction state. An alternative task or actor orchestration layer may
perform external work only by posting a detached, typed snapshot into the
serial inbox. It must never retain, mutate, or render live component or
application UI state. The runner owner remains the only authority that applies
the message and presents the resulting model.

## Presentation pipeline

The view pipeline has typed boundaries:

```text
component models -> styled surfaces -> declarative view -> cell differ -> bytes
```

A `Surface` is a value containing a rectangular vector of cells. Each origin
cell holds one grapheme-like glyph and a style. A two-column glyph owns a
continuation cell; overwriting either half clears the old span first. Writes and
overlays clip at surface boundaries.

`Layouts` builds new surfaces through padding, borders, alignment, horizontal
joins, and vertical joins. It does not retain parent pointers or application
callbacks.

A `View` pairs its frame with declarative alternate-screen, mouse, focus,
bracketed-paste, title, and cursor state. `Renderers` compares it with the prior
view, emits changed cells, and reconciles terminal modes. Applications never
construct cursor-motion or SGR byte strings.

## Theme boundary

`Themes.Theme` groups semantic style roles without changing component state or
the low-level rendering API. An application can copy `Themes.Charm`, replace
individual roles, and pass the value to component `Render` overloads. The
original explicit style parameters remain available when a component needs a
one-off treatment.

`Themes.Palette` is an additive, finer-grained render-time vocabulary. It keeps
ordinary content neutral while separating title/focus, interaction, selected,
button, pressed, and disabled states. `Themes.To_Theme` projects it onto the
stable `Theme` record, while high-value controls expose `From_Palette` to retain
the additional distinctions. Neither value is retained in a model.

| Component | Theme roles |
| --- | --- |
| Spinner | `Primary` |
| Progress | `Primary`, `Muted` |
| List | `Muted`, `Selected` |
| Text input | `Input`, `Placeholder` |
| Form | `Muted`, `Input`, `Focused` |
| Help | `Primary`, `Muted` |

`Border`, `Error`, and `Success` are application-facing roles for layout and
status presentation. Components borrow a theme only during rendering; models
never retain it. `Themes.Default` preserves terminal defaults. `Themes.Charm`
keeps content background-neutral; `Themes.Charm_Dark` and
`Themes.Charm_Light` are explicit variants for applications which know their
terminal background.

Chat message bodies and actions remain caller-owned surfaces. Selection styles
the message header and, when conversational padding exists, its accent rail;
it never replaces the bubble fill. Opaque text, transparent gaps, and embedded
component appearances therefore compose without selected-background cutouts.

## Input pipeline

`Input.Parser` accepts byte fragments up to its configured pending-byte bound.
It retains incomplete UTF-8 and escape sequences between calls and emits typed
events into a separately bounded queue for:

- printable and control keys;
- navigation and function keys, including xterm modifiers;
- focus changes;
- SGR mouse clicks, releases, motion, drag, and wheel input;
- bounded bracketed paste.

A leading escape is intentionally ambiguous. The POSIX backend waits for one
poll interval before calling `Flush_Escape`; an incomplete sequence then becomes
an Escape event followed by normally parsed suffix bytes. `Feed` raises
`Input_Error` instead of growing past either configured bound. Unknown complete
control sequences are consumed without exposing raw terminal commands to
applications.

## Mouse routing

Mouse events enter `Update` in terminal-cell coordinates. `Mouse.Region`
performs overflow-safe hit testing and translates matching events into local
component coordinates. Applications retain routing ownership because only the
application knows where a rendered component was placed.

Lists accept local row clicks and wheel selection, viewports accept vertical
and horizontal wheel scrolling, text inputs place their cursor on a local
left-click, and forms select fields and place the nested text cursor. Views may
request button events, button-drag cell motion, or all cell motion. Every mode
uses SGR coordinates and is disabled during backend restoration.

## Backend contract

`Backends.Backend` defines `Open`, `Current_Size`, `Next_Event`, `Render`,
`Interrupt`, and `Close`. It contains no file descriptor, `termios`, signal, or
Windows console type. `Current_Size` is a concrete, defaulted primitive: a
backend without an opening-size sample leaves the caller's unknown values
unchanged, preserving compatibility with minimal backends. When a sample is
available, the runner synchronously dispatches its resize before the first
render. `Close` is idempotent and must restore every terminal mode enabled by
the backend, including after partial initialization.

`Initialize` and the synthetic opening resize remain two ordered transitions.
The runner snapshots an initialize command, dispatches resize serially,
renders the resulting model, starts its workers, and then enqueues initialize
and resize commands in that order. Starting the command worker before those
puts preserves bounded backpressure even when command capacity is one.

`Backends.POSIX` currently supplies macOS and Linux operation:

- standard input is placed in raw mode;
- a nonblocking pipe wakes a blocked input poll;
- terminal size is observed at bounded intervals;
- the Ada parser handles all input policy;
- the Ada renderer handles frame and mode policy;
- controlled finalization provides a final restoration guard.

The C translation unit is a narrow ABI bridge for opaque `termios` storage,
`winsize`, `pollfd`, and descriptor flag macros. Parsing, retries beyond EINTR,
timeouts, rendering, ownership order, and error policy stay in Ada. See
[posix-bridge.md](posix-bridge.md).

`Backends.Headless` provides a bounded event source and records the most recent
view and render count. Tests may configure its opening size without consuming
an event-buffer entry. It exercises the same runner without changing a process
terminal.

## Components

Components own only local interaction state and return surfaces. They do not
start tasks, execute commands, or retain a backend. The current set includes:

- controls: buttons, check boxes, radio groups, selectors, dropdowns, tabs,
  accordions, and forms;
- navigation and data: breadcrumbs, lists, tables, trees, and viewports;
- telemetry: spinners, progress and progress groups, immediate indicators,
  sparklines, scrollbars, and streaming text;
- composition: boxes, split panes, panel groups with shared boundaries, and
  movable/resizable windows, plus application-composed menubars;
- editing and conversation: grapheme-aware text inputs and text areas,
  caller-budgeted syntax and Markdown editors/viewers, streaming text, and
  chat transcripts.

Applications decide how component state fits into their model and route events
explicitly. This keeps focus, validation, and command policy visible in the
application update function.

Chat owns bounded transcript metadata, viewport state, measurement snapshots,
and message presentation. Message bodies and actions are heterogeneous
caller-owned surfaces, so an embedded tool result is measured and routed by
the application that owns it. A composer is likewise a caller-owned text area
and button: the application routes both through the same immutable geometry
snapshot, rejects or accepts submission, and posts stable message values back
to the transcript. The component neither starts a streaming task nor retains
an application transport.

## Color profiles and gradients

The POSIX backend resolves an automatic or forced color policy to monochrome,
ANSI 16, ANSI 256, or truecolor. Rendering maps typed colors to the effective
profile; component and theme models remain independent of terminal escape
encoding. This keeps graceful fallback at the backend boundary and allows
headless tests to assert profiles deterministically.

Gradient components interpolate bounded color stops either per sRGB channel or
in linear light, then apply the result to foreground, background, or both.
Interpolation and direction are explicit model values. The kitchen sink Color
page labels the effective profile and fallback samples, compares identical
stops in both interpolation modes, and demonstrates foreground/background
application. Its `--color=auto|mono|ansi16|ansi256|truecolor` option makes each
policy directly inspectable.

## Responsive application layout

Component geometry belongs to the application, not to a backend or theme. A
responsive application derives an immutable layout snapshot from its current
terminal dimensions. The same snapshot must drive the corresponding `Present`
call, hit testing and coordinate localization, and cursor projection. This
prevents a resize from producing a frame with one geometry while input or the
cursor still uses another.

The kitchen sink demonstrates the contract with page-specific centered frames.
Card galleries use two columns from 72 cells and stack below that breakpoint;
each page has a readable maximum width and a bounded content height rather than
stretching sparse cards into terminal quadrants. Dedicated Markdown, Menus,
Chat, Panels, Windows, and Color pages may simplify their own regions at narrow
sizes. The Windows page is a bounded desktop; split-pane boundary interaction
belongs to Panels. The tab strip keeps the active page visible when every tab
does not fit. The header and tabs occupy the leading rows, help occupies the
final row when it fits, and page content receives the bounded remainder. On
each resize the application updates size-bearing component models before
presenting. Components whose content has an intrinsic width remain
application-owned children and are clipped by their assigned responsive
region.

## Runtime independence and future platforms

The crate does not depend on Flyology. Requiring Flyology would make a custom
GNAT runtime part of applications for which native Ada tasking is sufficient.
A future Flyology adapter may replace backend waiting or command execution, but
must preserve one model owner and one serial update path.

A Windows console implementation can implement the same backend lifecycle and
typed events. No Windows source is currently included, and POSIX behavior is
not conditionally embedded in the public interface.

## Invariants

- Only the runner owner mutates or presents the application model.
- `Initialize`, `Update`, and `Present` perform no external blocking I/O.
- A command receives a copied command value, never a model reference.
- Every dispatch begins with an empty transition.
- Terminal input and command queues are bounded.
- A submitted command is completed before structured runner shutdown returns.
- Backend `Close` is idempotent and safe after partial initialization.
- Backend `Interrupt` wakes a blocked `Next_Event` promptly.
- Terminal bytes are bounded, incremental, untrusted input.
- Renderer state consists of typed cells and modes, not application bytecode.
