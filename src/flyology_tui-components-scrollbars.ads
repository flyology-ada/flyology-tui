with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Layouts.Boxes;
with Flyology_TUI.Mouse;
with Flyology_TUI.Skins;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Scrollbars is
   subtype Orientation is Flyology_TUI.Layouts.Boxes.Direction;

   type Appearance is record
      Track         : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Thumb         : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused_Thumb : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Buttons       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Disabled      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   function Create
     (Flow   : Orientation;
      Length : Natural) return Model;

   --  Resize and Configure cancel thumb movement but preserve capture
   --  ownership until the next left release.
   procedure Resize (Item : in out Model; Length : Natural);
   procedure Configure
     (Item      : in out Model;
      Total     : Natural;
      Page_Size : Natural;
      First     : Natural);

   function First (Item : Model) return Natural;
   function Maximum_First (Item : Model) return Natural;
   function Region (Item : Model) return Flyology_TUI.Geometry.Rectangle;
   function Thumb_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle;

   procedure Focus (Item : in out Model);
   procedure Blur (Item : in out Model);
   function Focused (Item : Model) return Boolean;
   --  Disabling cancels thumb movement but preserves the pending release of
   --  an already-acquired mouse capture.
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);
   function Is_Enabled (Item : Model) return Boolean;

   --  Local mouse input supports arrow and track clicks, wheel movement, and
   --  captured thumb dragging. A release ends a captured drag even outside.
   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  Matching arrows move one item. Page Up/Down, Home, and End are
   --  supported.
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
      Appearance : Scrollbars.Appearance)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item       : Model;
      Appearance : Scrollbars.Appearance;
      Chrome     : Flyology_TUI.Skins.Scrollbar_Chrome)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item : Model;
      Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item  : Model;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

private
   type Model is tagged record
      Flow_Value : Orientation := Flyology_TUI.Layouts.Boxes.Vertical;
      Length     : Natural := 0;
      Total      : Natural := 0;
      Page       : Natural := 0;
      First_Item : Natural := 0;
      Enabled    : Boolean := True;
      Has_Focus  : Boolean := False;
      Dragging   : Boolean := False;
      Capturing  : Boolean := False;
      Drag_Offset : Natural := 0;
   end record;
end Flyology_TUI.Components.Scrollbars;
