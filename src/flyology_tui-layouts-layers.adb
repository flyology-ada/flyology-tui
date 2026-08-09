with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Components;

package body Flyology_TUI.Layouts.Layers is

   function Compose
     (Width, Height : Natural;
      Items         : Layer_Array) return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface;
   begin
      if Height /= 0 and then Width > Natural'Last / Height then
         raise Flyology_TUI.Components.Capacity_Error with
           "layer surface dimensions exceed addressable cell capacity";
      end if;

      Result := Flyology_TUI.Surfaces.Create (Width, Height);
      for Item of Items loop
         Result.Overlay_Clipped
           (Item.Content, Item.X, Item.Y, Item.Transparent_Spaces);
      end loop;
      return Result;
   end Compose;

   function Topmost_At
     (Items : Layer_Array;
      Point : Flyology_TUI.Geometry.Point) return Hit_Result
   is
      use Ada.Strings.Wide_Wide_Unbounded;
   begin
      for Index in reverse Items'Range loop
         declare
            Item : constant Layer := Items (Index);
            Bounds : constant Flyology_TUI.Geometry.Rectangle :=
              (X      => Item.X,
               Y      => Item.Y,
               Width  => Flyology_TUI.Surfaces.Width (Item.Content),
               Height => Flyology_TUI.Surfaces.Height (Item.Content));
         begin
            if Flyology_TUI.Geometry.Contains (Bounds, Point) then
               declare
                  Local : constant Flyology_TUI.Geometry.Point :=
                    (X => Point.X - Item.X,
                     Y => Point.Y - Item.Y);
                  Value : constant Flyology_TUI.Surfaces.Cell :=
                    Item.Content.Element
                      (Natural (Local.X), Natural (Local.Y));
                  Opaque : constant Boolean :=
                    not Item.Transparent_Spaces
                    or else Value.Continuation
                    or else To_Wide_Wide_String (Value.Glyph) /= " ";
               begin
                  if Opaque then
                     return
                       (Found => True, Index => Index, Local => Local);
                  end if;
               end;
            end if;
         end;
      end loop;
      return (Found => False);
   end Topmost_At;

end Flyology_TUI.Layouts.Layers;
