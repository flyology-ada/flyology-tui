with Flyology_TUI.Events;
with Flyology_TUI.Surfaces;

package Flyology_TUI.Components.Viewports is
   type Model is tagged private;

   function Create (Width, Height : Positive) return Model;
   procedure Set_Content
     (Item    : in out Model;
      Content : Flyology_TUI.Surfaces.Surface);
   procedure Resize (Item : in out Model; Width, Height : Positive);
   procedure Scroll (Item : in out Model; Delta_X, Delta_Y : Integer);
   --  Mouse coordinates are relative to Render. The wheel scrolls vertically,
   --  horizontally when reported by the terminal, or horizontally with Shift.
   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);
   function Render (Item : Model) return Flyology_TUI.Surfaces.Surface;

   function X_Offset (Item : Model) return Natural;
   function Y_Offset (Item : Model) return Natural;

private
   type Model is tagged record
      Content : Flyology_TUI.Surfaces.Surface;
      Columns : Positive := 1;
      Rows    : Positive := 1;
      X       : Natural := 0;
      Y       : Natural := 0;
   end record;
end Flyology_TUI.Components.Viewports;
