with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Windows is
   type Appearance is record
      Frame         : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused_Frame : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Title         : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused_Title : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Close         : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Content       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Disabled      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   function Create
     (X, Y                : Integer;
      Width, Height       : Positive;
      Minimum_Width       : Positive := 4;
      Minimum_Height      : Positive := 3;
      Closable            : Boolean := True;
      Movable             : Boolean := True;
      Resizable           : Boolean := True) return Model;

   function Bounds (Item : Model) return Flyology_TUI.Geometry.Rectangle;
   function Client_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle;
   function Client_Origin
     (Item : Model) return Flyology_TUI.Geometry.Point;

   procedure Focus (Item : in out Model);
   procedure Blur (Item : in out Model);
   function Focused (Item : Model) return Boolean;
   --  Disabling cancels movement, resize, or close activation. If the window
   --  already acquired mouse capture, the next left release still reports
   --  Release_Capture.
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);
   function Is_Enabled (Item : Model) return Boolean;

   --  Clamp the complete window to Workspace without synthesizing input.
   --  This is the application resize hook. It cancels movement, resize, or
   --  close activation, but preserves an already-acquired capture until the
   --  matching left-button release can report Release_Capture. An empty
   --  workspace uses the same origin-preserving policy as Handle.
   procedure Constrain_To
     (Item      : in out Model;
      Workspace : Flyology_TUI.Geometry.Rectangle);

   --  Mouse coordinates are relative to Workspace, not to the moving window.
   --  Captured drag and release events may therefore remain signed and outside
   --  the old bounds. A nonempty workspace clamps the complete window into it;
   --  when smaller than a configured minimum it temporarily becomes the
   --  effective minimum. An empty workspace preserves size and moves the
   --  origin to the workspace origin. Corners, side and bottom borders resize;
   --  the second top cell is the north-resize handle. The rest of the header
   --  moves the window except for its close control.
   function Handle
     (Item      : in out Model;
      Event     : Flyology_TUI.Mouse.Local_Event;
      Workspace : Flyology_TUI.Geometry.Rectangle)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  Alt-arrow moves, Control-arrow resizes, and Shift accelerates either.
   function Handle
     (Item      : in out Model;
      Event     : Flyology_TUI.Events.Terminal_Event;
      Workspace : Flyology_TUI.Geometry.Rectangle)
      return Flyology_TUI.Components.Interactions.Update_Result;

   procedure Update
     (Item      : in out Model;
      Event     : Flyology_TUI.Mouse.Local_Event;
      Workspace : Flyology_TUI.Geometry.Rectangle);

   procedure Update
     (Item      : in out Model;
      Event     : Flyology_TUI.Events.Terminal_Event;
      Workspace : Flyology_TUI.Geometry.Rectangle);

   --  Render a workspace-sized surface. Title and Content stay caller-owned.
   --  Signed clipping makes negative and partially offscreen bounds safe.
   function Render
     (Item       : Model;
      Title      : Wide_Wide_String;
      Content    : Flyology_TUI.Surfaces.Surface;
      Workspace  : Flyology_TUI.Geometry.Rectangle;
      Appearance : Windows.Appearance)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item      : Model;
      Title     : Wide_Wide_String;
      Content   : Flyology_TUI.Surfaces.Surface;
      Workspace : Flyology_TUI.Geometry.Rectangle;
      Theme     : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

private
   type Operation is
     (Idle, Moving, Closing,
      Resize_North, Resize_South, Resize_West, Resize_East,
      Resize_North_West, Resize_North_East,
      Resize_South_West, Resize_South_East);

   type Model is tagged record
      Area           : Flyology_TUI.Geometry.Rectangle;
      Minimum_Width  : Positive := 4;
      Minimum_Height : Positive := 3;
      Can_Close      : Boolean := True;
      Can_Move       : Boolean := True;
      Can_Resize     : Boolean := True;
      Enabled        : Boolean := True;
      Has_Focus      : Boolean := False;
      Active         : Operation := Idle;
      Capturing      : Boolean := False;
      Press_Point    : Flyology_TUI.Geometry.Point;
      Press_Area     : Flyology_TUI.Geometry.Rectangle;
   end record;
end Flyology_TUI.Components.Windows;
