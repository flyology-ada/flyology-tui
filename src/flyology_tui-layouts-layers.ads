with Flyology_TUI.Geometry;
with Flyology_TUI.Surfaces;

package Flyology_TUI.Layouts.Layers is
   type Layer is record
      Content            : Flyology_TUI.Surfaces.Surface;
      X                  : Integer := 0;
      Y                  : Integer := 0;
      Transparent_Spaces : Boolean := False;
   end record;

   type Layer_Array is array (Positive range <>) of Layer;

   type Hit_Result (Found : Boolean := False) is record
      case Found is
         when True =>
            Index : Positive;
            Local : Flyology_TUI.Geometry.Point;
         when False =>
            null;
      end case;
   end record;

   --  Items are painted in array order; the last item is topmost.
   function Compose
     (Width, Height : Natural;
      Items         : Layer_Array) return Flyology_TUI.Surfaces.Surface;

   --  Return the topmost painted cell at Point. A transparent space does not
   --  intercept input, while a wide glyph's continuation cell does.
   function Topmost_At
     (Items : Layer_Array;
      Point : Flyology_TUI.Geometry.Point) return Hit_Result;
end Flyology_TUI.Layouts.Layers;
