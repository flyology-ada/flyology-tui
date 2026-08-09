with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;

package Flyology_TUI.Layouts is
   type Edges is record
      Top    : Natural := 0;
      Right  : Natural := 0;
      Bottom : Natural := 0;
      Left   : Natural := 0;
   end record;

   type Horizontal_Alignment is (Align_Left, Align_Center, Align_Right);
   type Vertical_Alignment is (Align_Top, Align_Middle, Align_Bottom);

   type Border_Kind is (No_Border, Rounded, Square, Double_Line);

   type Block is record
      Width      : Natural := 0;
      Height     : Natural := 0;
      Padding    : Edges;
      Border     : Border_Kind := No_Border;
      Appearance : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Horizontal : Horizontal_Alignment := Align_Left;
      Vertical   : Vertical_Alignment := Align_Top;
   end record;

   function Render
     (Item    : Block;
      Content : Flyology_TUI.Surfaces.Surface)
      return Flyology_TUI.Surfaces.Surface;

   function Join_Horizontally
     (Left, Right : Flyology_TUI.Surfaces.Surface;
      Gap         : Natural := 0;
      Alignment   : Vertical_Alignment := Align_Top)
      return Flyology_TUI.Surfaces.Surface;

   function Join_Vertically
     (Top, Bottom : Flyology_TUI.Surfaces.Surface;
      Gap         : Natural := 0;
      Alignment   : Horizontal_Alignment := Align_Left)
      return Flyology_TUI.Surfaces.Surface;
end Flyology_TUI.Layouts;
