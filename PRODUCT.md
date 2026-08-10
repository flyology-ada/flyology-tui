# Product

## Register

product

## Users

Flyology TUI serves Ada application authors who want to build typed terminal
interfaces with a serial, Elm-style model/update/view loop. They should not
need to adopt a separate asynchronous language, a particular task runtime, or
web-interface conventions to build an expressive TUI.

## Product Purpose

Flyology TUI is an independent Ada crate of bounded retained components,
terminal rendering primitives, input parsing, and application orchestration.
Applications own state, effects, composition, z-order, and heterogeneous child
content. Flyology integration may be added through an adapter, but the crate
does not depend on Flyology.

The primary demonstration is the kitchen sink. It is a legible component
gallery and interaction reference at compact, medium, and wide terminal sizes,
not a debug dump. Every shown control communicates its purpose, current state,
focus, and interaction affordance.

## Brand Personality

- Precise: typed state, explicit bounds, stable alignment, and deterministic
  interaction.
- Playful: restrained accent color, useful Unicode marks, sparklines, and deep
  gradients where terminal capability permits.
- Terminal-native: compact, cell-aware, keyboard-first without excluding the
  mouse, and respectful of terminal defaults.

The visual language is inspired by the implementation discipline of Charm's
terminal libraries: clear state, compact composition, typed messages, and
small reusable primitives. It is not a visual copy of the Charm website.

## Anti-references

- Sparse full-screen quadrants with tiny controls in distant corners.
- Raw implementation notes or diagnostic dumps presented as product content.
- Website-like hero sections, oversized branding, and ornamental whitespace.
- Components whose state is apparent only through color.
- Themes retained inside component models or styling coupled to behavior.

## Design Principles

- One application owner serializes model updates and presentation.
- Components are bounded retained models; caller-owned content remains caller
  owned.
- Themes and `Appearance` records are external values supplied at presentation
  time.
- Responsive applications compute one immutable geometry snapshot and use it
  for rendering, hit testing, capture routing, and cursor placement.
- Large terminals improve composition and readable working area, not the
  distance between unrelated controls.
- Windows remains a backend boundary; POSIX is implemented first and Windows
  support is not implied yet.

## Accessibility

- Keyboard and mouse interaction are equal supported paths.
- Unicode input, display width, clipping, selection, and cursor projection are
  consistent across components.
- Monochrome, ANSI 16-color, ANSI 256-color, and truecolor terminals degrade
  predictably without losing non-color attributes or state visibility.
- Color is never the sole carrier of focus, selection, status, or meaning.
- Palette choices vary lightness and terminal attributes so common forms of
  color-vision deficiency do not erase hierarchy.
- Essential actions retain textual labels; decorative Unicode glyphs never
  replace their meaning.
