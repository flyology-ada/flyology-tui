with Ada.Containers.Vectors;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Layouts.Boxes;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Panel_Groups is
   subtype Orientation is Flyology_TUI.Layouts.Boxes.Direction;

   type Pane_Constraint is record
      Minimum_Span : Natural := 0;
      Initial_Span : Natural := 0;
      Weight       : Positive := 1;
   end record;

   --  Array bounds are retained by Model. Pane and divider query indices use
   --  the same bounds supplied by the caller; divider I is between panes I
   --  and I + 1.
   type Pane_Constraint_Array is
     array (Integer range <>) of Pane_Constraint;
   type Surface_Array is
     array (Integer range <>) of Flyology_TUI.Surfaces.Surface;

   type Appearance is record
      Pane             : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Divider          : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Focused_Divider  : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Hovered_Divider  : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Pressed_Divider  : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Disabled_Divider : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;
   type Layout_Snapshot is private;

   --  Horizontal groups arrange panes left to right; Vertical groups arrange
   --  them top to bottom. Minimums are assigned in pane order when they do not
   --  fit. Otherwise preferred Initial_Span values are filled in pane order,
   --  and remaining cells are divided by Weight. Each visible divider owns
   --  one cell. In a geometry too small for every divider, earlier dividers
   --  are visible first and every pane span is zero.
   function Create
     (Flow          : Orientation;
      Width, Height : Natural;
      Panes         : Pane_Constraint_Array) return Model;

   --  Resize preserves current spans in pane order before distributing growth
   --  by Weight. Configure replaces the pane range and returns to the initial
   --  span policy. Both operations validate the complete result before
   --  changing Model, cancel an active drag, and preserve capture ownership
   --  until the matching left-button release.
   procedure Resize
     (Item          : in out Model;
      Width, Height : Natural);
   procedure Configure
     (Item  : in out Model;
      Panes : Pane_Constraint_Array);
   procedure Configure
     (Item          : in out Model;
      Width, Height : Natural;
      Panes         : Pane_Constraint_Array);

   function Flow (Item : Model) return Orientation;
   function Width (Item : Model) return Natural;
   function Height (Item : Model) return Natural;
   function Bounds (Item : Model) return Flyology_TUI.Geometry.Rectangle;
   function Pane_Count (Item : Model) return Natural;
   function Divider_Count (Item : Model) return Natural;
   function Has_Pane (Item : Model; Index : Integer) return Boolean;
   function Has_Divider (Item : Model; Index : Integer) return Boolean;
   function Pane_Span (Item : Model; Index : Integer) return Natural
     with Pre => Has_Pane (Item, Index);
   function Pane_Region
     (Item : Model; Index : Integer) return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Pane (Item, Index);
   function Divider_Region
     (Item : Model; Index : Integer) return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Divider (Item, Index);

   --  Capture the complete geometry after Configure or Resize. A snapshot is
   --  independent of later model changes and can be shared by the parent's
   --  mouse router and the matching Render call.
   function Layout (Item : Model) return Layout_Snapshot;
   function Flow (Item : Layout_Snapshot) return Orientation;
   function Width (Item : Layout_Snapshot) return Natural;
   function Height (Item : Layout_Snapshot) return Natural;
   function Bounds
     (Item : Layout_Snapshot) return Flyology_TUI.Geometry.Rectangle;
   function Pane_Count (Item : Layout_Snapshot) return Natural;
   function Divider_Count (Item : Layout_Snapshot) return Natural;
   function Has_Pane
     (Item : Layout_Snapshot; Index : Integer) return Boolean;
   function Has_Divider
     (Item : Layout_Snapshot; Index : Integer) return Boolean;
   function Pane_Span
     (Item : Layout_Snapshot; Index : Integer) return Natural
     with Pre => Has_Pane (Item, Index);
   function Pane_Region
     (Item : Layout_Snapshot;
      Index : Integer) return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Pane (Item, Index);
   function Divider_Region
     (Item : Layout_Snapshot;
      Index : Integer) return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Divider (Item, Index);

   procedure Focus (Item : in out Model);
   procedure Blur (Item : in out Model);
   function Focused (Item : Model) return Boolean;
   procedure Focus_Divider (Item : in out Model; Index : Integer)
     with Pre => Has_Divider (Item, Index);
   function Has_Focused_Divider (Item : Model) return Boolean;
   function Focused_Divider (Item : Model) return Integer
     with Pre => Has_Focused_Divider (Item);

   --  Disabling cancels the semantic drag and hover state. If capture was
   --  already acquired, the next matching left release still reports
   --  Release_Capture.
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);
   function Is_Enabled (Item : Model) return Boolean;

   --  Coordinates are local to the fixed group origin. Captured drag and
   --  release coordinates remain signed outside the old or current Bounds.
   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  Keyboard input is accepted only while focused and enabled. Tab selects
   --  the next divider, Shift-Tab the previous, Home the first, and End the
   --  last. Left/Right move a Horizontal divider; Up/Down move a Vertical
   --  divider. Movement is one cell, or five with Shift, and never violates
   --  either neighboring minimum when all configured minimums fit.
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

   --  Children and themes are borrowed for this call. Children must have the
   --  same bounds used to configure Model. Each child is clipped and padded
   --  inside its pane, so a wide glyph cannot cross or overwrite a divider.
   function Render
     (Item       : Model;
      Children   : Surface_Array;
      Appearance : Panel_Groups.Appearance)
      return Flyology_TUI.Surfaces.Surface;
   function Render
     (Item       : Model;
      Geometry   : Layout_Snapshot;
      Children   : Surface_Array;
      Appearance : Panel_Groups.Appearance)
      return Flyology_TUI.Surfaces.Surface;
   function Render
     (Item     : Model;
      Children : Surface_Array;
      Theme    : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;
   function Render
     (Item     : Model;
      Geometry : Layout_Snapshot;
      Children : Surface_Array;
      Theme    : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

private
   type Pane_State is record
      Minimum : Natural := 0;
      Initial : Natural := 0;
      Weight  : Positive := 1;
      Span    : Natural := 0;
   end record;

   package Pane_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Pane_State);

   type Layout_Snapshot is record
      Flow_Value       : Orientation :=
        Flyology_TUI.Layouts.Boxes.Horizontal;
      Columns          : Natural := 0;
      Rows             : Natural := 0;
      First_Pane_Index : Integer := 1;
      Panes            : Pane_Vectors.Vector;
   end record;

   type Model is tagged record
      Flow_Value       : Orientation :=
        Flyology_TUI.Layouts.Boxes.Horizontal;
      Columns          : Natural := 0;
      Rows             : Natural := 0;
      First_Pane_Index : Integer := 1;
      Panes            : Pane_Vectors.Vector;
      Enabled          : Boolean := True;
      Has_Focus        : Boolean := False;
      Focused_Position : Natural := 0;
      Has_Hover        : Boolean := False;
      Hover_Position   : Natural := 0;
      Dragging         : Boolean := False;
      Drag_Position    : Natural := 0;
      Capturing        : Boolean := False;
      Press_Coordinate : Integer := 0;
      Press_First_Span : Natural := 0;
      Press_Second_Span : Natural := 0;
   end record;
end Flyology_TUI.Components.Panel_Groups;
