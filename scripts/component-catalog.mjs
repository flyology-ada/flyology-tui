const commonOwnership = [
  "The application owns the model and applies updates in its serial event loop.",
  "Appearance and skin values are borrowed only while the component renders."
];

const component = (value) => ({
  ownership: commonOwnership,
  keyboard: "Keyboard and mouse paths produce the same typed state transition.",
  ...value
});

export const components = [
  component({
    slug: "accordions", title: "Accordions", group: "Navigation",
    summary: "Expand bounded sections while callers retain each section body.",
    use: "Use an accordion when several related sections share one narrow region and users usually need one section at a time.",
    model: "The model stores stable section IDs, expansion state, focus, and capture. Body surfaces remain caller-owned.",
    interaction: "Arrow keys move between headers. Enter, Space, and matching mouse release toggle the focused section.",
    kind: "accordion",
    code: `Presentation := Item.Present (Bodies, Width, Look);\nFrame := Accordions.Frame (Presentation);`
  }),
  component({
    slug: "breadcrumbs", title: "Breadcrumbs", group: "Navigation",
    summary: "Show a bounded path with stable IDs and responsive truncation.",
    use: "Use breadcrumbs to show hierarchy and let users return to an ancestor without opening a separate menu.",
    model: "Active and focused items survive reorder by stable ID. Width changes recompute visible items and ellipses.",
    interaction: "Left and Right move focus. Enter, Space, or mouse activation returns the selected ancestor ID.",
    kind: "breadcrumbs",
    code: `Crumbs.Set_Items (Path);\nCrumbs.Resize (Width);\nFrame := Crumbs.Render (Look);`
  }),
  component({
    slug: "buttons", title: "Buttons", group: "Controls",
    summary: "Activate a labeled command after a complete press and release gesture.",
    use: "Use a button for an immediate, named action. Keep persistent choices in check boxes, radios, or selectors.",
    model: "The label and appearance stay outside the interaction model. The model retains focus, hover, armed state, and capture.",
    interaction: "Enter and Space activate immediately. A mouse press arms the button; only a matching release inside activates it.",
    kind: "button",
    code: `Button.Update (Event, Result);\nif Result.Activated then\n   Save;\nend if;`
  }),
  component({
    slug: "chats", title: "Chats", group: "Content",
    summary: "Virtualize heterogeneous messages, actions, a footer, and a composer.",
    use: "Use Chats for ordinary conversations or AI transcripts whose message bodies can be any caller-owned component surface.",
    model: "The chat owns stable message metadata, measurements, viewport state, selection, follow-tail state, and unread counts. Bodies remain external.",
    interaction: "Route input to visible child body and action regions before transcript scrolling. The application owns composer submission.",
    kind: "chat",
    code: `Plan := Chat.Plan (Frame_Width, Frame_Height);\nView := Chat.Present (Plan, Bodies, Actions, Footer, Composer, Look);`
  }),
  component({
    slug: "check-boxes", sourceSlug: "check_boxes", title: "Check boxes", group: "Controls",
    summary: "Represent unchecked, checked, and mixed boolean state.",
    use: "Use a check box for an independent option. Use a radio group when exactly one choice should remain active.",
    model: "The model retains tri-state value and interaction state. Programmatic setters cancel stale activation without losing pending release ownership.",
    interaction: "Space toggles the focused value. A mouse gesture toggles only after a matching release.",
    kind: "checkbox",
    code: `Check.Update (Event, Result);\nif Result.Changed then\n   Apply (Check.State);\nend if;`
  }),
  component({
    slug: "dock-workspaces", sourceSlug: "dock_workspaces", title: "Dock workspaces", group: "Layout",
    summary: "Dock, collapse, float, move, and restore caller-owned panes.",
    use: "Use a dock workspace when users must reorganize major tool panes while the application retains global ownership.",
    model: "At most one pane occupies each edge. Floating panes retain their return edge, and an immutable presentation aligns render and hit regions.",
    interaction: "Headers support mouse drag and keyboard docking. Collapsed rails remain focusable, and matching release always unwinds capture.",
    kind: "dock",
    code: `Layout := Workspace.Present (Bounds, Children, Skin);\nWorkspace.Update (Event, Layout, Result);`
  }),
  component({
    slug: "dropdowns", title: "Dropdowns", group: "Controls",
    summary: "Choose one stable-ID item from a bounded popup list.",
    use: "Use a dropdown when one choice must fit in a compact closed control. Prefer radios when all choices should stay visible.",
    model: "The model retains selected ID, highlight, open state, focus, and capture. Item labels are supplied by the generic instance.",
    interaction: "Enter or Space opens and commits. Escape and outside click dismiss. Arrow keys and wheel movement change the highlight.",
    kind: "dropdown",
    code: `Picker.Update (Event, Result);\nif Result.Activated then\n   Use (Picker.Selected_Id);\nend if;`
  }),
  component({
    slug: "forms", title: "Forms", group: "Content",
    summary: "Lay out labels and caller-owned field surfaces in bounded rows.",
    use: "Use Forms to align related input fields and values. Field interaction and validation remain in each child model.",
    model: "The form retains responsive width and label-column geometry, not the child field models or their values.",
    interaction: "The application routes events to child regions returned by the form layout and owns focus traversal.",
    kind: "form",
    code: `Form.Resize (Width);\nFrame := Form.Render (Fields, Look);\nRegion := Form.Field_Region (Name_Field);`
  }),
  component({
    slug: "gradients", title: "Gradients", group: "Visualization",
    summary: "Apply bounded semantic color gradients to complete terminal cells.",
    use: "Use gradients to communicate progression, intensity, or grouping on high-color terminals while retaining a useful reduced-color result.",
    model: "A fixed-capacity stop model validates order atomically. Rendering preserves glyphs, attributes, and complete wide spans.",
    interaction: "Gradients are presentation-only. Color profiles progressively reduce truecolor output to ANSI 256, ANSI 16, or monochrome.",
    kind: "gradient",
    code: `Ramp.Set_Stops (Stops);\nRamp.Apply (Surface, Region, Horizontal, Foreground);`
  }),
  component({
    slug: "help", title: "Help", group: "Feedback",
    summary: "Render compact key and command hints horizontally or vertically.",
    use: "Use Help for persistent shortcuts near the surface they affect. Keep long explanations in guide text.",
    model: "Help is stateless. The caller supplies bounded bindings and explicit key and detail styles.",
    interaction: "Help renders labels only and never consumes input.",
    kind: "help",
    code: `Frame := Help.Render\n  (Bindings, Width, Vertical => False, Theme => Theme);`
  }),
  component({
    slug: "indicators", title: "Indicators", group: "Feedback",
    summary: "Render badges, dividers, gauges, key-value rows, and status lines.",
    use: "Use indicators for compact, read-only state that must remain legible beside interactive controls.",
    model: "Indicator renderers are stateless. Status-line capacity is explicit and rejected before partial output.",
    interaction: "Indicators do not take focus or consume events.",
    kind: "indicators",
    code: `Status := Indicators.Status_Line\n  (Items, Width, Appearance);`
  }),
  component({
    slug: "interactions", title: "Interaction results", group: "Foundation",
    summary: "Share handled, changed, activation, rejection, focus, and capture results.",
    use: "Use the common result vocabulary when an application coordinates several components without callbacks.",
    model: "Update_Result is a detached value. Capture actions explicitly acquire or release application-owned mouse capture.",
    interaction: "Applications inspect the result after Update, mutate their own domain state, then schedule another render.",
    kind: "interaction",
    code: `Control.Update (Event, Result);\nApply_Capture (Owner, Result.Capture);`
  }),
  component({
    slug: "lists", title: "Lists", group: "Navigation",
    summary: "Navigate a bounded vertical list with responsive viewport geometry.",
    use: "Use Lists for simple homogeneous rows. Use Tables for columns and Trees for hierarchy.",
    model: "The model retains focus, selected row, top row, and configured dimensions. Content surfaces remain external.",
    interaction: "Arrows, Page Up, Page Down, Home, End, wheel, and row clicks move the visible selection safely at numeric limits.",
    kind: "list",
    code: `List.Resize (Width, Height);\nList.Update (Event, Result);\nFrame := List.Render (Rows, Theme);`
  }),
  component({
    slug: "markdown-editors", sourceSlug: "markdown_editors", title: "Markdown editors", group: "Editing",
    summary: "Compose a bounded source editor with live Markdown preview layouts.",
    use: "Use Markdown_Editors when users need source, preview, or responsive split modes from one bounded document.",
    model: "A limited model owns one text area and one viewer in place. Text mutations synchronize the preview; cursor-only changes do not reset it.",
    interaction: "The application routes input to the source or preview region from the current immutable layout.",
    kind: "markdownEditor",
    code: `Editor.Set_Mode (Split_Vertical);\nEditor.Update_Source (Event, Result);\nEditor.Advance_Preview (Line_Budget => 8);`
  }),
  component({
    slug: "markdown-viewers", sourceSlug: "markdown_viewers", title: "Markdown viewers", group: "Content",
    summary: "Parse and present a bounded read-only Markdown subset incrementally.",
    use: "Use Markdown_Viewers for documentation, help, or message bodies that need links and structured text without web rendering.",
    model: "The viewer owns bounded source, line, link, parse, scroll, and selection state. Parsing and rendering advance under caller budgets.",
    interaction: "Keyboard and mouse activate typed link IDs. Stale presentation snapshots are rejected after source replacement.",
    kind: "markdown",
    code: `Viewer.Try_Set_Source (Text, Result);\nViewer.Advance_Parsing (Line_Budget => 16);\nFrame := Viewer.Present (Render_Budget => 20);`
  }),
  component({
    slug: "menubars", title: "Menubars", group: "Navigation",
    summary: "Present typed top-level, popup, and nested application commands.",
    use: "Use a menubar for global commands that need mnemonics, shortcuts, check items, radio items, and bounded submenus.",
    model: "The model validates the menu graph atomically and preserves mutable state by stable ID. Presentation revisions reject stale overlay input.",
    interaction: "Menus take modal routing priority while open. Keyboard mnemonics, arrows, Escape, mouse hover, and complete click gestures have parity.",
    kind: "menubar",
    code: `Menu.Set_Content (Definitions);\nLayout := Menu.Present (Viewport, Look);\nMenu.Update (Event, Layout, Result);`
  }),
  component({
    slug: "panel-groups", sourceSlug: "panel_groups", title: "Panel groups", group: "Layout",
    summary: "Resize an arbitrary bounded sequence of panes at shared dividers.",
    use: "Use Panel_Groups for jointly resizable horizontal or vertical work areas with more than two children.",
    model: "Initial sizes, weights, minima, pane bounds, focused divider, and capture stay in the model. Children remain caller-owned.",
    interaction: "Drag a shared divider with the mouse or move the focused divider with arrows. Tab changes the focused divider.",
    kind: "panels",
    code: `Layout := Group.Layout;\nGroup.Update (Event, Layout, Result);\nFrame := Group.Render (Layout, Children, Skin);`
  }),
  component({
    slug: "progress", title: "Progress", group: "Feedback",
    summary: "Render a single determinate progress value at a responsive width.",
    use: "Use Progress for one bounded operation. Use Progress_Groups when several jobs need selection, lifecycle, and aggregate state.",
    model: "The model retains current value, maximum, width, and label geometry. It never owns a timer or task.",
    interaction: "Progress is read-only. The application advances it through ordinary model updates.",
    kind: "progress",
    code: `Bar.Set_Value (Completed);\nBar.Resize (Width);\nFrame := Bar.Render (Theme);`
  }),
  component({
    slug: "progress-groups", sourceSlug: "progress_groups", title: "Progress groups", group: "Feedback",
    summary: "Track typed jobs with determinate, indeterminate, and lifecycle states.",
    use: "Use Progress_Groups for a bounded set of work items that need selection, aggregate progress, and distinct work states.",
    model: "Stable typed IDs survive reorder. Phase changes occur only through explicit Advance calls; no timer or task is retained.",
    interaction: "Keyboard, wheel, and local mouse input select rows. Rendering can show rows or a deterministic segmented aggregate.",
    kind: "progressGroup",
    code: `Jobs.Set_Value (Build_Id, 42);\nJobs.Advance;\nFrame := Jobs.Render_Rows (Height, Look);`
  }),
  component({
    slug: "radio-groups", sourceSlug: "radio_groups", title: "Radio groups", group: "Controls",
    summary: "Select exactly one stable-ID option from a visible bounded group.",
    use: "Use radio groups when comparing all choices matters and exactly one item should be active.",
    model: "The model retains selected and focused IDs plus capture. Disabled items remain present but are skipped by navigation.",
    interaction: "Arrows move and select. Enter, Space, and matching mouse release activate the focused identity.",
    kind: "radio",
    code: `Choices.Update (Event, Result);\nif Result.Activated then\n   Apply (Choices.Selected_Id);\nend if;`
  }),
  component({
    slug: "scrollbars", title: "Scrollbars", group: "Navigation",
    summary: "Bind a viewport offset to arrow, track, wheel, and thumb input.",
    use: "Use Scrollbars beside a real scrollable region. The application owns the two-way synchronization with content offsets.",
    model: "The model retains orientation, range, page size, first item, focus, and capture. It does not own the scrolled content.",
    interaction: "Arrows move one unit, track clicks move one page, wheel moves by signed magnitude, and thumb drag uses captured motion.",
    kind: "scrollbar",
    code: `Bar.Configure (Content, Page, First);\nBar.Update (Event, Result);\nViewport.Set_Offset (Bar.First);`
  }),
  component({
    slug: "selectors", title: "Selectors", group: "Controls",
    summary: "Select one or several stable-ID items from a visible list.",
    use: "Use Selectors when choices should stay visible and multi-selection may be required.",
    model: "Single and multiple modes share bounded item storage. Replace_Selection validates the complete new selection before mutation.",
    interaction: "Arrows move focus. Space and mouse release toggle according to the configured selection mode.",
    kind: "selector",
    code: `Selection.Update (Event, Result);\nif Result.Changed then\n   Read_Selected_Ids;\nend if;`
  }),
  component({
    slug: "sparklines", title: "Sparklines", group: "Visualization",
    summary: "Render a bounded numeric suffix as a compact bar series.",
    use: "Use Sparklines when trend and shape matter more than exact axis labels.",
    model: "The caller supplies a fixed-capacity numeric series. Automatic or fixed scaling validates finite values before glyph selection.",
    interaction: "Sparklines are read-only and take no focus.",
    kind: "sparkline",
    code: `Series.Append (Sample);\nFrame := Chart.Render (Series, Width, Theme);`
  }),
  component({
    slug: "spinners", title: "Spinners", group: "Feedback",
    summary: "Show caller-advanced activity without owning time or work.",
    use: "Use a spinner for activity whose completion ratio is unknown. Prefer progress when a useful ratio exists.",
    model: "The model retains one bounded phase. The application calls Advance from its own tick event.",
    interaction: "Spinners do not take focus or schedule updates.",
    kind: "spinner",
    code: `Spinner.Advance;\nFrame := Spinner.Render (Theme);`
  }),
  component({
    slug: "split-panes", sourceSlug: "split_panes", title: "Split panes", group: "Layout",
    summary: "Resize two caller-owned panes at one shared boundary.",
    use: "Use Split_Panes for a two-region editor, navigator, or preview. Use Panel_Groups for three or more panes.",
    model: "The model retains orientation, first span, minima, focus, and capture. Resize computes deterministic child and divider regions.",
    interaction: "Drag the divider or use arrows while focused. Matching release unwinds capture after resize or disable changes.",
    kind: "split",
    code: `Split.Resize (Width, Height);\nSplit.Update (Event, Result);\nFrame := Split.Render (Left, Right, Look);`
  }),
  component({
    slug: "streaming-texts", sourceSlug: "streaming_texts", title: "Streaming texts", group: "Content",
    summary: "Append bounded output with follow-tail and unseen-history state.",
    use: "Use Streaming_Texts for logs, command output, or AI response text that arrives in chunks.",
    model: "Fixed code-point, line, and viewport-cell capacities bound retained output. Append can reject or trim complete old lines and clusters.",
    interaction: "Keyboard and wheel input scroll. The caller appends chunks and explicitly finishes, fails, or cancels the stream.",
    kind: "stream",
    code: `Stream.Append (Chunk, Trim_Oldest, Result);\nStream.Finish;\nFrame := Stream.Render (Look);`
  }),
  component({
    slug: "syntax-editors", sourceSlug: "syntax_editors", title: "Syntax editors", group: "Editing",
    summary: "Compose bounded multiline editing with caller-budgeted token highlighting.",
    use: "Use Syntax_Editors when source text needs responsive editing plus a deterministic external lexer.",
    model: "One text-area state machine owns editing. A bounded per-line token cache stores validated cluster-boundary spans and lexer state.",
    interaction: "Editing behavior matches Text_Areas. The caller advances highlighting under an explicit line budget.",
    kind: "syntax",
    code: `Editor.Update (Event, Result);\nEditor.Advance_Highlighting (Line_Budget => 8);\nFrame := Editor.Render (Look);`
  }),
  component({
    slug: "tables", title: "Tables", group: "Data",
    summary: "Render typed columns, stable rows, sorting, selection, and viewport state.",
    use: "Use Tables for homogeneous records whose columns need independent widths and sort behavior.",
    model: "Source order and display order stay separate. Stable row IDs preserve selection and focus through reorder and stable sorting.",
    interaction: "Header focus controls three-state sorting. Row focus controls selection and vertical navigation; wheel input changes the viewport.",
    kind: "table",
    code: `Table.Set_Rows (Rows);\nTable.Update (Event, Result);\nFrame := Table.Render (Columns, Look);`
  }),
  component({
    slug: "tabs", title: "Tabs", group: "Navigation",
    summary: "Switch stable-ID pages with responsive clipping and persistent active state.",
    use: "Use Tabs for sibling views at one hierarchy level. Keep application-wide commands in a menubar.",
    model: "The model retains active and focused IDs. An immutable presentation maps visible tab regions after clipping.",
    interaction: "Arrows move focus, Enter and Space activate, and matching mouse release activates the pressed tab.",
    kind: "tabs",
    code: `Layout := Tabs.Present (Width, Skin, Focused);\nTabs.Update (Event, Layout, Result);`
  }),
  component({
    slug: "text-areas", sourceSlug: "text_areas", title: "Text areas", group: "Editing",
    summary: "Edit bounded multiline Unicode text with selection, history, and wrapping.",
    use: "Use Text_Areas for multiline input, notes, source, or a composer. Use Streaming_Texts for non-editable append-only output.",
    model: "A limited model owns normalized LF text, cursor, selection, bounded undo history, viewport, and capture. Capacity rejection is atomic.",
    interaction: "Grapheme-aware keys, page movement, wheel scrolling, click-drag selection, paste, undo, and redo share one state machine.",
    kind: "textarea",
    code: `Editor.Update (Event, Result);\nif Result.Changed then\n   Save (Editor.Value);\nend if;`
  }),
  component({
    slug: "text-inputs", sourceSlug: "text_inputs", title: "Text inputs", group: "Editing",
    summary: "Edit one bounded Unicode line with cursor and selection state.",
    use: "Use Text_Inputs for names, filters, paths, and short commands that must remain on one line.",
    model: "The model retains bounded value, cursor, selection, horizontal viewport, focus, and capture. Labels and appearance remain external.",
    interaction: "Keyboard editing, paste, pointer placement, and drag selection operate on grapheme boundaries.",
    kind: "textinput",
    code: `Input.Update (Event, Result);\nFrame := Input.Render (Placeholder, Look);`
  }),
  component({
    slug: "trees", title: "Trees", group: "Data",
    summary: "Navigate a validated bounded preorder tree with stable expansion state.",
    use: "Use Trees for hierarchical data whose children can expand and collapse in place.",
    model: "Set_Items validates preorder depth atomically. Expansion, selection, focus, and viewport survive replacement by stable ID.",
    interaction: "Left collapses or moves to the parent. Right expands or moves to the first child. Rows also support mouse and wheel input.",
    kind: "tree",
    code: `Tree.Set_Items (Nodes);\nTree.Update (Event, Result);\nFrame := Tree.Render (Look);`
  }),
  component({
    slug: "viewports", title: "Viewports", group: "Layout",
    summary: "Clip a caller-owned surface and expose bounded horizontal and vertical offsets.",
    use: "Use Viewports when content can exceed its visible region. Pair them with Scrollbars when users need persistent position affordances.",
    model: "The viewport retains visible size and offsets, not the content surface. Offset setters clamp to current content bounds.",
    interaction: "Arrows, Page keys, and wheel input move offsets. The application synchronizes any attached scrollbar models.",
    kind: "viewport",
    code: `Viewport.Set_Content_Size (Content.Width, Content.Height);\nViewport.Update (Event, Result);\nFrame := Viewport.Render (Content);`
  }),
  component({
    slug: "windows", title: "Windows", group: "Layout",
    summary: "Move, resize, focus, close, and layer in-terminal surfaces.",
    use: "Use Windows for floating work surfaces inside a terminal workspace. The application still owns z-order and modal routing.",
    model: "The model retains bounds, minima, enabled state, focus, and capture. Titles, content, appearance, and child models stay external.",
    interaction: "Drag the header to move and any border or corner to resize. Alt arrows move; Ctrl arrows resize; close returns a typed request.",
    kind: "window",
    code: `Window.Update (Event, Workspace, Result);\nif Result.Close_Requested then\n   Hide (Window_Id);\nend if;`
  })
];

export const groups = [
  "Controls", "Editing", "Navigation", "Data", "Layout",
  "Content", "Feedback", "Visualization", "Foundation"
];

export const skins = [
  { id: "charm-default", label: "Charm", frame: "single",
    colors: { desktop: "#f3eff8", panel: "#fbf9fd", text: "#2d2833",
      muted: "#756d7d", border: "#9688a4", accent: "#7958d8",
      selected: "#e8def7", control: "#f3edf8", success: "#238b68",
      shadow: "#d7ccdf", danger: "#b63a64" } },
  { id: "charm-dark", label: "Charm dark", frame: "single",
    colors: { desktop: "#15121b", panel: "#211b29", text: "#f0e9f6",
      muted: "#a89caf", border: "#796986", accent: "#c09bf6",
      selected: "#49325f", control: "#2b2234", success: "#5bd3a2",
      shadow: "#0b0910", danger: "#ff7da9" } },
  { id: "charm-light", label: "Charm light", frame: "single",
    colors: { desktop: "#faf8fc", panel: "#fffdfd", text: "#29252e",
      muted: "#716a78", border: "#a094aa", accent: "#5a56e0",
      selected: "#e8e5fb", control: "#f3f1f8", success: "#208764",
      shadow: "#ded8e2", danger: "#b83266" } },
  { id: "turbo-vision", label: "Turbo Vision", frame: "double",
    colors: { desktop: "#0000a8", panel: "#a8a8a8", text: "#000000",
      muted: "#545454", border: "#ffffff", accent: "#0000a8",
      selected: "#00a800", control: "#00a8a8", success: "#00a800",
      shadow: "#000000", danger: "#a80000" } }
];
