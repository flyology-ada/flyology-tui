with Flyology_TUI.Geometry;
with Flyology_TUI.Surfaces;

package Flyology_TUI.Layouts.Boxes is
   type Direction is (Horizontal, Vertical);
   type Constraint_Kind is (Content, Fixed, Fill);

   type Constraint (Kind : Constraint_Kind := Content) is record
      case Kind is
         when Content =>
            null;
         when Fixed =>
            Cells : Natural := 0;
         when Fill =>
            Weight : Positive := 1;
      end case;
   end record;

   Content_Size : constant Constraint := (Kind => Content);
   function Fixed_Size (Cells : Natural) return Constraint;
   function Fill_Size (Weight : Positive := 1) return Constraint;

   type Surface_Array is
     array (Positive range <>) of Flyology_TUI.Surfaces.Surface;
   type Constraint_Array is array (Positive range <>) of Constraint;

   type Layout_Result (Item_Count : Natural) is tagged private;

   function Arrange
     (Items       : Surface_Array;
      Constraints : Constraint_Array;
      Width        : Natural;
      Height       : Natural;
      Flow         : Direction;
      Gap          : Natural := 0) return Layout_Result;

   function Horizontally
     (Items       : Surface_Array;
      Constraints : Constraint_Array;
      Width        : Natural;
      Height       : Natural;
      Gap          : Natural := 0) return Layout_Result;

   function Vertically
     (Items       : Surface_Array;
      Constraints : Constraint_Array;
      Width        : Natural;
      Height       : Natural;
      Gap          : Natural := 0) return Layout_Result;

   function Frame
     (Item : Layout_Result) return Flyology_TUI.Surfaces.Surface;

   function Region
     (Item  : Layout_Result;
      Index : Positive) return Flyology_TUI.Geometry.Rectangle
     with Pre => Index <= Item.Item_Count;

private
   type Region_Array is
     array (Positive range <>) of Flyology_TUI.Geometry.Rectangle;

   type Layout_Result (Item_Count : Natural) is tagged record
      Frame_Value : Flyology_TUI.Surfaces.Surface;
      Regions     : Region_Array (1 .. Item_Count);
   end record;
end Flyology_TUI.Layouts.Boxes;
