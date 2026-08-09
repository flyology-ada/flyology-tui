# Flyology TUI

Flyology TUI is an experimental, typed terminal user-interface toolkit for
Ada. It follows the model/message/update/view structure associated with Elm and
Bubble Tea while retaining Ada value types, in-place model updates, and normal
tasking semantics.

The crate is independent from the Flyology runtime and builds with stock GNAT.
Its backend boundary is intended to support a native POSIX implementation
first, a Windows console implementation later, and an optional Flyology-aware
adapter without changing application code.

## Status

The repository currently contains the transition kernel and the public backend
contract:

- strongly typed terminal and application events;
- application-defined, strongly typed command values;
- serial `Initialize` and `Update` transitions;
- declarative terminal view properties;
- a limited backend interface for input, rendering, restoration, and wakeup;
- behavioral tests for transition reset, message dispatch, command emission,
  view construction, and termination.

There is not yet a terminal renderer. The next milestone is the POSIX session,
input decoder, styled cell surface, and frame differ.

## Programming model

An application declares its own model, message, and command types. Instantiating
`Flyology_TUI.Application_Events` produces the closed event sum; instantiating
`Flyology_TUI.Transitions` produces typed effect declarations. A
`Flyology_TUI.Programs` instance connects those types to the application's
callbacks.

```ada
type Model is limited record
   Count : Integer := 0;
end record;

type Message is record
   Amount : Integer;
end record;

type Command is (No_Command, Save);

package Events is new Flyology_TUI.Application_Events (Message);
package Transitions is new Flyology_TUI.Transitions (Command);
```

Only the event-loop owner passes the model to `Start`, `Dispatch`, and
`Current_View`. Other tasks communicate by posting application messages.
Blocking work belongs in command executors, and command results re-enter through
`Events.From_Message`.

The model is deliberately mutable. The architecture requires unidirectional
ownership and explicit effects, not functional data structures or model copies.

## Build and test

Alire 2.1 or newer is recommended.

```sh
alr build
alr test
```

The test suite is a nested Alire crate pinned to the parent library, keeping
test-only build state outside the published dependency set.

## License

Flyology TUI is available under either the MIT License or the Apache License
2.0, at your option.
