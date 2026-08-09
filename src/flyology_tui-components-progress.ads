with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;

package Flyology_TUI.Components.Progress is
   subtype Fraction is Long_Float range 0.0 .. 1.0;

   type Model is tagged private;

   function Create
     (Width      : Positive := 40;
      Show_Value : Boolean := True) return Model;

   procedure Set (Item : in out Model; Value : Fraction);
   function Value (Item : Model) return Fraction;

   function Render
     (Item       : Model;
      Complete   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Remaining  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface;

private
   type Model is tagged record
      Current    : Fraction := 0.0;
      Columns    : Positive := 40;
      Show_Value : Boolean := True;
   end record;
end Flyology_TUI.Components.Progress;
