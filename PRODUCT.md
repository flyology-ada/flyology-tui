# Product

Flyology TUI is an independent Ada crate for building typed terminal user
interfaces. It serves Ada application authors who want a serial, Elm-style
model/update/view loop without adopting a separate asynchronous language or a
particular task runtime.

The product should feel precise, playful, and terminal-native. Components are
bounded retained models; applications own state, effects, composition,
z-order, and heterogeneous child content. Themes and component appearances are
ordinary external values supplied at presentation time. Flyology integration
may be added through an adapter, but the crate does not depend on Flyology.

The primary demonstration is the kitchen sink. It must be a legible component
gallery and interaction reference at compact, medium, and wide terminal sizes,
not a debug dump. Every shown control should communicate its purpose, current
state, focus, and interaction affordance.

## Product requirements

- Keyboard and mouse interaction are equal supported paths.
- Unicode input, display width, clipping, selection, and cursor projection are
  consistent across components.
- Monochrome, ANSI 16-color, ANSI 256-color, and truecolor terminals degrade
  predictably without losing non-color attributes or state visibility.
- Color is never the sole carrier of focus, selection, status, or meaning.
- Responsive applications compute one immutable geometry snapshot and use it
  for rendering, hit testing, capture routing, and cursor placement.
- Windows remains a backend boundary; POSIX is implemented first and Windows
  is not implied to work yet.

The visual language is inspired by the implementation discipline of Charm's
terminal libraries: clear state, compact composition, typed messages, and
small reusable primitives. It is not a visual copy of the Charm website.

