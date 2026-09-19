with Flyology_TUI.Styles;

--  Borrowed render-time styling for one caller-owned text buffer. A
--  Span_Array is supplied to a Render call and is never retained by a
--  component model, exactly as a Theme is never retained. The caller
--  recomputes the overlay when its buffer changes, so highlighting policy
--  stays outside the components that draw it.
package Flyology_TUI.Components.Highlights is

   --  A styled half-open code-point range [First, Last) measured from the
   --  start of the styled buffer. Last <= First denotes an empty span. This
   --  is the offset convention Text_Areas.Cursor_Offset and the
   --  Syntax_Editors token contract already use.
   --  @field First First code-point offset the span covers
   --  @field Last Code-point offset immediately after the covered range
   --  @field Look Style applied to every covered code point
   type Span is record
      First : Natural := 0;
      Last : Natural := 0;
      Look : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   --  An overlay. Index order matters only where two spans overlap.
   type Span_Array is array (Positive range <>) of Span;

   --  The overlay that styles nothing. This is the empty set rather than a
   --  policy choice, and it lets a Render profile default its overlay.
   None : constant Span_Array (1 .. 0) := (1 .. 0 => <>);

   --  Return the style for the code point at Offset. Spans are applied in
   --  array order and a later span wins on overlap, so an unsorted or
   --  overlapping overlay stays deterministic and needs no validation.
   --  Offsets that no span covers keep Base.
   --  @param Spans Overlay to resolve against
   --  @param Offset Code-point offset being styled
   --  @param Base Style used where no span applies
   --  @return Style the overlay resolves for Offset
   function Style_At
     (Spans  : Span_Array;
      Offset : Natural;
      Base   : Flyology_TUI.Styles.Style)
      return Flyology_TUI.Styles.Style;

   --  Return whether every span is non-empty and begins at or after the
   --  previous span's end. Rendering never requires this; callers that want
   --  the stricter contract can assert it.
   --  @param Spans Overlay to examine
   --  @return True when the overlay is ordered and non-overlapping
   function Is_Ordered (Spans : Span_Array) return Boolean;

   --  Build an overlay from the incremental token contract Syntax_Editors
   --  uses. Both take the same Next_Token procedure, so one lexer can feed a
   --  full editor and a prompt line without being written twice.
   --  @formal Token_Kind Token vocabulary the lexer reports
   --  @formal Lexer_State State carried between tokens and across line feeds
   --  @formal Initial_State State supplied to the first token call
   --  @formal Next_Token Reports one token, or the line's final state
   generic
      type Token_Kind is (<>);
      type Lexer_State is private;
      Initial_State : Lexer_State;
      --  Called repeatedly for one line. The first call for a line receives
      --  the preceding line's final state (or Initial_State); each later
      --  call receives Final from the previous token call. From is the prior
      --  token's exclusive end. A no-token call supplies the line's final
      --  state.
      --  @param Line Text of the line being scanned, without its line feed
      --  @param Initial State carried into this call
      --  @param From Exclusive end of the previous token on this line
      --  @param Kind Token vocabulary member the token belongs to
      --  @param First Code-point offset the token starts at
      --  @param Last Code-point offset immediately after the token
      --  @param Final State to carry into the next call
      --  @param Has_Token False when the line has no further token
      with procedure Next_Token
        (Line        : Wide_Wide_String;
         Initial     : Lexer_State;
         From        : Natural;
         Kind        : out Token_Kind;
         First, Last : out Natural;
         Final       : out Lexer_State;
         Has_Token   : out Boolean);
   package Lexers is

      --  Style for each token kind, borrowed while scanning.
      type Token_Appearance is
        array (Token_Kind) of Flyology_TUI.Styles.Style;

      --  Outcome of one scan.
      --  @enum Scan_Complete Every line was scanned to its end
      --  @enum Scan_Capacity_Limited The overlay ran out of room
      --  @enum Scan_Structure_Invalid The lexer reported an unusable token
      --  @enum Scan_Lexer_Failed The lexer propagated an exception
      type Scan_State is
        (Scan_Complete,
         Scan_Capacity_Limited,
         Scan_Structure_Invalid,
         Scan_Lexer_Failed);

      --  Scan Value one logical line at a time, carrying lexer state across
      --  line feeds, and write one span per token. Offsets in the result are
      --  absolute within Value, so the overlay can be passed straight to a
      --  Render call.
      --
      --  Scanning stops once Spans'Length tokens are written
      --  (Scan_Capacity_Limited), on a token that is empty, out of order,
      --  past the end of its line, or not on a grapheme-cluster boundary
      --  (Scan_Structure_Invalid), and on any exception the lexer propagates
      --  (Scan_Lexer_Failed). Count always reports the spans written before
      --  scanning stopped, so a partial overlay remains renderable.
      --  @param Value Whole buffer to scan, line feeds included
      --  @param Look Style to apply to each token kind
      --  @param Spans Overlay the scan writes into
      --  @param Count Number of spans written
      --  @param Status Why scanning stopped
      procedure Scan
        (Value  : Wide_Wide_String;
         Look   : Token_Appearance;
         Spans  : out Span_Array;
         Count  : out Natural;
         Status : out Scan_State);

   end Lexers;

end Flyology_TUI.Components.Highlights;
