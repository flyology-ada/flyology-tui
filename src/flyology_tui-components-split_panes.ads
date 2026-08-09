with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Layouts.Boxes;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Split_Panes is
   subtype Orientation is Flyology_TUI.Layouts.Boxes.Direction;

   type Appearance is record
      Background : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Divider : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Focused_Divider : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   function Create
     (Flow           : Orientation;
      Width, Height  : Natural;
      First_Span     : Natural;
      First_Minimum  : Natural := 0;
      Second_Minimum : Natural := 0) return Model;

   procedure Resize
     (Item : in out Model;
      Width, Height : Natural);

   function First_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle;
   function Second_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle;
   function Divider_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle;
   function First_Span (Item : Model) return Natural;

   procedure Focus (Item : in out Model);
   procedure Blur (Item : in out Model);
   function Focused (Item : Model) return Boolean;

   --  Coordinates are local to the complete split pane. During a captured
   --  divider drag they may be outside it. If both minimums cannot fit, the
   --  first minimum has deterministic priority and the second receives the
   --  remaining cells.
   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  The arrows matching Flow move the focused divider; Shift accelerates.
   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event);

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);

   function Render
     (Item       : Model;
      First      : Flyology_TUI.Surfaces.Surface;
      Second     : Flyology_TUI.Surfaces.Surface;
      Appearance : Split_Panes.Appearance)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item   : Model;
      First  : Flyology_TUI.Surfaces.Surface;
      Second : Flyology_TUI.Surfaces.Surface;
      Theme  : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

private
   type Model is tagged record
      Flow_Value     : Orientation := Flyology_TUI.Layouts.Boxes.Horizontal;
      Columns        : Natural := 0;
      Rows           : Natural := 0;
      First_Value    : Natural := 0;
      First_Minimum  : Natural := 0;
      Second_Minimum : Natural := 0;
      Has_Focus      : Boolean := False;
      Dragging       : Boolean := False;
   end record;
end Flyology_TUI.Components.Split_Panes;
