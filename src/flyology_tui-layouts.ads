with Flyology_TUI.Geometry;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Skins;

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

   --  Render with caller-selected structural chrome. The old overload keeps
   --  Border_Kind's exact glyphs and has no shadow.
   function Render
     (Item    : Block;
      Content : Flyology_TUI.Surfaces.Surface;
      Chrome  : Flyology_TUI.Skins.Frame_Chrome)
      return Flyology_TUI.Surfaces.Surface;

   --  Return the local rectangle available to content after the block's
   --  border, padding, and frame shadow. Item.Width and Item.Height are exact
   --  outer extents for this query, including zero; intrinsic dimensions have
   --  no content slot until the caller supplies an explicit block extent.
   --  @param Item Block whose explicit outer extent defines the local frame.
   --  @param Chrome Frame structure used by the matching Render overload.
   --  @return Exact local rectangle available to caller-owned content.
   function Content_Region
     (Item   : Block;
      Chrome : Flyology_TUI.Skins.Frame_Chrome)
      return Flyology_TUI.Geometry.Rectangle;

   --  Return a panel's local content rectangle. Leading titles reserve their
   --  rendered heading and gap; centered titles occupy the border and reserve
   --  no content row. The result excludes the frame shadow.
   --  @param Item Block whose explicit outer extent defines the local panel.
   --  @param Chrome Panel structure used by the matching panel renderer.
   --  @return Exact local rectangle available to caller-owned panel content.
   function Panel_Content_Region
     (Item   : Block;
      Chrome : Flyology_TUI.Skins.Panel_Chrome)
      return Flyology_TUI.Geometry.Rectangle;

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
