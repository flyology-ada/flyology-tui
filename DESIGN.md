# Design

Flyology TUI uses an externally themed terminal design system. Component
models retain interaction state and geometry, never a theme. `Appearance`
records map semantic roles to styles at render time, and the renderer adapts
semantic colors to the active terminal profile.

## Character

- Precise: stable alignment, explicit bounds, visible focus, deterministic
  clipping, and no ambiguous ownership.
- Playful: restrained accent color, useful Unicode marks, sparklines, and deep
  gradients where terminal capability permits.
- Terminal-native: dense enough to scan, readable in cells, useful without a
  mouse, and respectful of terminal defaults.

Avoid sparse full-screen quadrants, isolated intrinsic-size cards in distant
corners, raw implementation notes presented as content, website-like hero
layouts, and color-only interaction states. A large terminal should produce a
centered coherent gallery, not larger gaps between the same small controls.

## Responsive composition

The kitchen sink uses three width bands: compact below 72 cells, medium from
72 through 111, and wide from 112. Each page owns named regions within a
centered maximum-width frame. Compact pages stack, medium pages generally use
two columns, and wide pages use the arrangement appropriate to their content.
Unused height trails the gallery; it is not distributed between unrelated
cards. Editors, chat, panels, and window desktops explicitly opt into filling
available height.

Cards fill their assigned region, with one-cell internal padding and one- or
two-cell gutters. Readable prose and chat messages are capped near 72 cells.
Geometry that becomes empty is not focusable or clickable.

## Interaction and accessibility

Persistent glyphs, borders, labels, and inverse/attribute changes accompany
color changes. Keyboard traversal follows visual order. Captured mouse release
is routed to its owner even outside the original bounds. Modal menu overlays
receive input before underlying content. User-authored text always exposes a
terminal cursor derived from the same layout that was drawn.

Monochrome output must retain hierarchy and active state. Palette choices
should remain distinguishable under common color-vision deficiencies by also
varying lightness and terminal attributes. Unicode glyphs require ASCII-safe
spacing and correct cell-width accounting; they may decorate but not replace
essential labels.
