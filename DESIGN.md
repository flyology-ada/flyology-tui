# Design

Flyology TUI uses an externally themed terminal design system. Component
models retain interaction state and geometry, never a theme. `Appearance`
records map semantic roles to styles at render time, and the renderer adapts
semantic colors to the active terminal profile.

Full skins remain render-time values. They combine a semantic palette with
desktop fill and structural chrome for frames, tabs, windows, and docks.
Switching a skin must not replace a component model, alter stable IDs, or
change input geometry. A preset may change one-cell tab markers, border glyphs,
close marks, and clipped shadows when those substitutions preserve the same
published regions.

## Character

- Precise: stable alignment, explicit bounds, visible focus, deterministic
  clipping, and no ambiguous ownership.
- Playful: restrained accent color, useful Unicode marks, sparklines, and deep
  gradients where terminal capability permits.
- Terminal-native: dense enough to scan, readable in cells, useful without a
  mouse, and respectful of terminal defaults.
- Skin-coherent: presets change the complete visual grammar, not merely an
  accent color. Charm uses soft grouping and persistent state cues; the Turbo
  Vision-inspired preset uses the later Borland vocabulary: a blue desktop and
  work windows; gray menu/status bars and dialogs; cyan choice fields; green
  commands; centered border titles; single inactive and double active frames;
  hard offset shadows; depressed buttons; textured scrollbars; and red menu
  mnemonics.

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

Dock workspaces are an optional composition layer above ordinary panels and
windows, not a global manager. At most one pane occupies each edge; collapsed
docks retain a visible rail, floating panes retain their return edge, and the
remaining center is a caller-owned region. One immutable presentation supplies
the rendered frame, child regions, chrome hits, and floating z-order. Dropping
a floating header on a free edge and the equivalent keyboard command perform
the same state transition.

## Backlog

- Add a bounded drag-and-drop substrate with typed payloads, immutable
  presentation-aligned source and target regions, explicit capture, accept,
  reject, cancel, and release results, and complete keyboard parity. Edge
  auto-scroll remains an application policy rather than hidden component work.
- Build sortable and reorderable list, table, tree, and panel adapters on that
  substrate. Stable IDs survive reorder, and a drop commits atomically to
  caller-owned data only after the target accepts it.
- Add a dedicated streaming-text kitchen-sink card. Demonstrate append,
  follow-tail, unseen chunks, trim and reject policies, terminal states,
  scrolling, and responsive wrapping without requiring users to infer the
  component from the Chat page.

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
