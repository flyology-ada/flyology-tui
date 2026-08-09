with Ada.Containers.Vectors;
with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Styles;

package Flyology_TUI.Surfaces is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Cell is record
      Glyph        : Text.Unbounded_Wide_Wide_String :=
        Text.To_Unbounded_Wide_Wide_String (" ");
      Appearance   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Continuation : Boolean := False;
   end record;

   type Surface is tagged private;

   function Create
     (Width, Height : Natural;
      Fill          : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
      return Surface;

   function From_Text
     (Content : Wide_Wide_String;
      Appearance : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
      return Surface;

   function Width (Item : Surface) return Natural;
   function Height (Item : Surface) return Natural;

   function Element (Item : Surface; X, Y : Natural) return Cell
     with Pre => X < Width (Item) and then Y < Height (Item);

   procedure Clear
     (Item : in out Surface;
      Fill : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default);

   procedure Put
     (Item       : in out Surface;
      X, Y       : Natural;
      Glyph      : Wide_Wide_String;
      Appearance : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default);

   procedure Write
     (Item       : in out Surface;
      X, Y       : Natural;
      Content    : Wide_Wide_String;
      Appearance : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default);

   procedure Overlay
     (Target             : in out Surface;
      Source             : Surface;
      X, Y               : Natural;
      Transparent_Spaces : Boolean := False);

   --  Overlay at a signed origin. Partially clipped wide glyphs become styled
   --  blanks in their visible cells, never orphan continuation cells.
   procedure Overlay_Clipped
     (Target             : in out Surface;
      Source             : Surface;
      X, Y               : Integer;
      Transparent_Spaces : Boolean := False);

private
   package Cell_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Cell);

   type Surface is tagged record
      Columns : Natural := 0;
      Rows    : Natural := 0;
      Cells   : Cell_Vectors.Vector;
   end record;
end Flyology_TUI.Surfaces;
