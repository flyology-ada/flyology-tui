with Ada.Containers.Vectors;
with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

--  A bounded completion candidate set and its popup. The model owns the
--  candidates, the buffer range an accepted candidate replaces, and the
--  selection; it never computes candidates itself, because what completes
--  is application policy. One immutable presentation snapshot drives
--  rendering and hit testing alike.
--  @formal Category Caller vocabulary for candidate kinds
--  @formal Capacity Greatest number of candidates retained at one time
generic
   type Category is (<>);
   Capacity : Positive;
package Flyology_TUI.Components.Completions is

   --  Local name for the unbounded wide-string type candidates are built
   --  from.
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   --  One offered completion.
   --  @field Insert Text placed in the caller's buffer when accepted
   --  @field Display Text the popup shows for this candidate
   --  @field Detail Right-aligned annotation in the detailed menu
   --  @field Kind Selects a style from Category_Appearance
   type Candidate is record
      Insert  : Text.Unbounded_Wide_Wide_String;
      Display : Text.Unbounded_Wide_Wide_String;
      Detail  : Text.Unbounded_Wide_Wide_String;
      Kind    : Category := Category'First;
   end record;

   --  Build a candidate. An empty Display shows the inserted text.
   --  @param Insert Text placed in the caller's buffer when accepted
   --  @param Display Text the popup shows, or empty to show Insert
   --  @param Detail Right-aligned annotation in the detailed menu
   --  @param Kind Selects a style from Category_Appearance
   --  @return The assembled candidate
   function Candidate_Of
     (Insert  : Wide_Wide_String;
      Display : Wide_Wide_String := "";
      Detail  : Wide_Wide_String := "";
      Kind    : Category := Category'First) return Candidate;

   --  A caller-owned set of candidates to offer.
   type Candidate_Array is array (Positive range <>) of Candidate;

   --  How the popup arranges its candidates.
   --  @enum Tabulated_Grid Equal-width columns filled column-major
   --  @enum Detailed_Menu One candidate per row with its detail text
   type Presentation_Mode is (Tabulated_Grid, Detailed_Menu);

   --  Style for each candidate kind, borrowed while rendering.
   type Category_Appearance is
     array (Category) of Flyology_TUI.Styles.Style;

   --  Render-time styles. Both presentations also draw a two-cell selection
   --  mark, so the selection survives a monochrome profile and an
   --  all-default Appearance.
   --  @field Normal Style for an unselected candidate
   --  @field Selected Style for the selected candidate
   --  @field Detail Style for a candidate's annotation
   --  @field Counter Style for the clipped-candidate counter row
   --  @field Categories Per-kind tint layered over Normal
   type Appearance is record
      Normal     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selected   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Detail     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Counter    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Categories : Category_Appearance :=
        (others => Flyology_TUI.Styles.Default);
   end record;

   --  Map the compact semantic theme onto popup styles.
   --  @param Theme Borrowed semantic theme
   --  @return Styles for this component
   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   --  Map the richer semantic palette onto popup styles.
   --  @param Palette Borrowed semantic palette
   --  @return Styles for this component
   function From_Palette
     (Palette : Flyology_TUI.Themes.Palette) return Appearance;

   --  A closed popup retaining no candidates.
   type Model is tagged private;

   --  Width and Max_Rows are the cells the application has agreed to give
   --  the popup. Both may be zero, which publishes no geometry at all.
   --  @param Mode How candidates are arranged
   --  @param Width Cells the popup may use horizontally
   --  @param Max_Rows Rows the popup may use, counter row included
   --  @return A closed popup with that geometry
   function Create
     (Mode     : Presentation_Mode;
      Width    : Natural;
      Max_Rows : Natural) return Model;

   --  Outcome of one Offer.
   --  @enum Offered Every supplied candidate was retained
   --  @enum Offered_Truncated Only the first Capacity were retained
   --  @enum Closed_Empty No candidate was supplied, so the popup closed
   --  @enum Rejected_Span The span was inverted; nothing changed
   type Offer_Result is
     (Offered,
      Offered_Truncated,
      Closed_Empty,
      Rejected_Span);

   --  Replace the candidate set and open the popup. Replace_First and
   --  Replace_Last are the half-open code-point range of the caller's
   --  buffer that an accepted candidate's Insert text replaces; the model
   --  retains the range but never touches the buffer.
   --  @param Item Popup to fill
   --  @param Values Candidates to offer
   --  @param Replace_First Code-point offset the replacement starts at
   --  @param Replace_Last Code-point offset after the replaced range
   --  @return Whether every candidate was retained
   function Offer
     (Item          : in out Model;
      Values        : Candidate_Array;
      Replace_First : Natural;
      Replace_Last  : Natural) return Offer_Result;

   --  Report whether the popup is offering candidates.
   --  @param Item Popup to inspect
   --  @return True while the popup is offering candidates
   function Is_Open (Item : Model) return Boolean;

   --  Close the popup and discard its candidates.
   --  @param Item Popup to close
   procedure Close (Item : in out Model);

   --  Applications call Dismiss when routing a click outside the popup.
   --  @param Item Popup to dismiss
   --  @return Whether the dismissal was handled, and capture released
   function Dismiss
     (Item : in out Model)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  Count the retained candidates.
   --  @param Item Popup to measure
   --  @return Number of retained candidates
   function Length (Item : Model) return Natural;

   --  Report whether any candidate is retained.
   --  @param Item Popup to measure
   --  @return True when no candidate is retained
   function Is_Empty (Item : Model) return Boolean;

   --  Read one retained candidate.
   --  @param Item Popup to inspect
   --  @param Position One-based position of the wanted candidate
   --  @return The candidate at that position
   function Candidate_At
     (Item : Model; Position : Positive) return Candidate
     with Pre => Position <= Length (Item);

   --  Report which candidate is selected.
   --  @param Item Popup to inspect
   --  @return Selected position, or zero when nothing is retained
   function Selected_Index (Item : Model) return Natural;

   --  Read the selected candidate.
   --  @param Item Popup to inspect
   --  @return The currently selected candidate
   function Selected_Candidate (Item : Model) return Candidate
     with Pre => not Is_Empty (Item);

   --  Report where an accepted candidate starts replacing.
   --  @param Item Popup to inspect
   --  @return Code-point offset the replacement starts at
   function Replacement_First (Item : Model) return Natural;

   --  Report where an accepted candidate stops replacing.
   --  @param Item Popup to inspect
   --  @return Code-point offset after the replaced range
   function Replacement_Last (Item : Model) return Natural;

   --  Longest prefix shared by every retained candidate's Insert text,
   --  trimmed to a grapheme-cluster boundary so a partial completion never
   --  splits a cluster. Inserting it is what a first completion key does
   --  when several candidates remain.
   --  @param Item Popup to inspect
   --  @return The shared prefix, possibly empty
   function Common_Prefix (Item : Model) return Wide_Wide_String;

   --  Select the next candidate, wrapping past the end.
   --  @param Item Popup to move within
   procedure Select_Next (Item : in out Model);

   --  Select the previous candidate, wrapping past the start.
   --  @param Item Popup to move within
   procedure Select_Previous (Item : in out Model);

   --  Select the first candidate.
   --  @param Item Popup to move within
   procedure Select_First (Item : in out Model);

   --  Select the last candidate.
   --  @param Item Popup to move within
   procedure Select_Last (Item : in out Model);

   --  Move one column toward the end in Tabulated_Grid, or one page in
   --  Detailed_Menu, because a menu has one column.
   --  @param Item Popup to move within
   procedure Select_Next_Column (Item : in out Model);

   --  Move one column toward the start, or one page in Detailed_Menu.
   --  @param Item Popup to move within
   procedure Select_Previous_Column (Item : in out Model);

   --  Select an existing position, or clear the selection with zero.
   --  @param Item Popup to move within
   --  @param Position Position to select, or zero to select nothing
   procedure Select_Position (Item : in out Model; Position : Natural)
     with Pre => Position <= Length (Item);

   --  Change how candidates are arranged.
   --  @param Item Popup to rearrange
   --  @param Mode How candidates are arranged
   procedure Set_Mode (Item : in out Model; Mode : Presentation_Mode);

   --  Report how candidates are arranged.
   --  @param Item Popup to inspect
   --  @return How candidates are arranged
   function Mode (Item : Model) return Presentation_Mode;

   --  Change the cells the popup may use. The scroll offset is corrected,
   --  so growing the popup never leaves candidates stranded off-window.
   --  @param Item Popup to resize
   --  @param Width Cells the popup may use horizontally
   --  @param Max_Rows Rows the popup may use, counter row included
   procedure Set_Size
     (Item : in out Model; Width : Natural; Max_Rows : Natural);

   --  Report the cells the popup may use horizontally.
   --  @param Item Popup to inspect
   --  @return Cells the popup may use horizontally
   function Width (Item : Model) return Natural;

   --  Report the rows the popup may use.
   --  @param Item Popup to inspect
   --  @return Rows the popup may use
   function Max_Rows (Item : Model) return Natural;

   --  One immutable geometry snapshot. Rendering, hit testing, and the
   --  clipped-candidate counter all read the same value, so a popup can
   --  never accept a click on a cell it did not draw.
   type Presentation is private;

   --  Compute the geometry the popup would draw right now.
   --  @param Item Popup to measure
   --  @return The geometry snapshot
   function Layout (Item : Model) return Presentation;

   --  Report the rows the snapshot draws.
   --  @param Item Geometry snapshot
   --  @return Drawn rows, counter row included
   function Height (Item : Presentation) return Natural;

   --  Report the candidate columns the snapshot draws.
   --  @param Item Geometry snapshot
   --  @return Number of candidate columns
   function Columns (Item : Presentation) return Natural;

   --  Report the rows that carry candidates.
   --  @param Item Geometry snapshot
   --  @return Rows carrying candidates, counter row excluded
   function Content_Rows (Item : Presentation) return Natural;

   --  Report how many candidates precede the first drawn one.
   --  @param Item Geometry snapshot
   --  @return Candidates scrolled past before the first drawn one
   function First_Visible (Item : Presentation) return Natural;

   --  Count the candidates the snapshot draws.
   --  @param Item Geometry snapshot
   --  @return Number of candidates actually drawn
   function Visible_Count (Item : Presentation) return Natural;

   --  Count the candidates the snapshot cannot show.
   --  @param Item Geometry snapshot
   --  @return Candidates the published geometry cannot show
   function Hidden_Count (Item : Presentation) return Natural;

   --  Report whether the snapshot draws a counter row.
   --  @param Item Geometry snapshot
   --  @return True when a counter row is drawn
   function Has_Counter_Row (Item : Presentation) return Boolean;

   --  Resolve a local cell to the candidate drawn on it. Structural cells,
   --  such as the gutter between columns, carry no candidate.
   --  @param Item Geometry snapshot
   --  @param X Local cell column
   --  @param Y Local cell row
   --  @return Candidate position, or zero for a cell drawing none
   function Position_At_Cell
     (Item : Presentation; X, Y : Natural) return Natural;

   --  Move the selection, activate it, or close the popup. A popup with no
   --  published geometry is inert, so it never holds keys an application
   --  cannot see it consuming.
   --  @param Item Popup receiving the key
   --  @param Event Terminal event to interpret
   --  @return Whether the key was handled, and what it changed
   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  Coordinates are relative to the surface Render returns.
   --  @param Item Popup receiving the event
   --  @param Event Component-local mouse event
   --  @return Whether the event was handled, and what it changed
   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  Apply a key and discard the result.
   --  @param Item Popup receiving the key
   --  @param Event Terminal event to interpret
   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);

   --  Apply a mouse event and discard the result.
   --  @param Item Popup receiving the event
   --  @param Event Component-local mouse event
   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event);

   --  Draw the popup with explicit styles.
   --  @param Item Popup to draw
   --  @param Look Borrowed styles
   --  @return A surface of the published geometry
   function Render
     (Item : Model; Look : Appearance)
      return Flyology_TUI.Surfaces.Surface;

   --  Draw the popup with styles derived from a theme.
   --  @param Item Popup to draw
   --  @param Theme Borrowed semantic theme
   --  @return A surface of the published geometry
   function Render
     (Item : Model; Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

private
   package Candidate_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Candidate);

   type Presentation is record
      Shape        : Presentation_Mode := Tabulated_Grid;
      Cells        : Natural := 0;
      Column_Cells : Natural := 0;
      Column_Count : Natural := 0;
      Row_Count    : Natural := 0;
      Offset       : Natural := 0;
      Visible      : Natural := 0;
      Hidden       : Natural := 0;
      Counter      : Boolean := False;
   end record;

   type Model is tagged record
      Values    : Candidate_Vectors.Vector;
      Selected  : Natural := 0;
      Offset    : Natural := 0;
      First_Cut : Natural := 0;
      Last_Cut  : Natural := 0;
      Shape     : Presentation_Mode := Tabulated_Grid;
      Cells     : Natural := 0;
      Rows      : Natural := 0;
      Opened    : Boolean := False;
   end record;
end Flyology_TUI.Components.Completions;
