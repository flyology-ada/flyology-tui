with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;

package Flyology_TUI.Components.Spinners is
   type Spinner_Style is (Dots, Line, Pulse);
   type Model is tagged private;

   function Create (Kind : Spinner_Style := Dots) return Model;
   procedure Tick (Item : in out Model);
   procedure Start (Item : in out Model);
   procedure Stop (Item : in out Model);
   function Running (Item : Model) return Boolean;

   function Render
     (Item       : Model;
      Appearance : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface;

private
   type Model is tagged record
      Kind     : Spinner_Style := Dots;
      Position : Natural := 0;
      Active   : Boolean := True;
   end record;
end Flyology_TUI.Components.Spinners;
