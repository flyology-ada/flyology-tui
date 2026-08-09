with Flyology_TUI.Components;

package body Flyology_TUI.Layouts.Boxes is

   type Size_Array is array (Positive range <>) of Natural;

   function Fixed_Size (Cells : Natural) return Constraint is
     ((Kind => Fixed, Cells => Cells));

   function Fill_Size (Weight : Positive := 1) return Constraint is
     ((Kind => Fill, Weight => Weight));

   function Intrinsic_Size
     (Item : Flyology_TUI.Surfaces.Surface;
      Flow : Direction) return Natural
   is (case Flow is
          when Horizontal => Flyology_TUI.Surfaces.Width (Item),
          when Vertical   => Flyology_TUI.Surfaces.Height (Item));

   function Intrinsic_Cross_Size
     (Item : Flyology_TUI.Surfaces.Surface;
      Flow : Direction) return Natural
   is (case Flow is
          when Horizontal => Flyology_TUI.Surfaces.Height (Item),
          when Vertical   => Flyology_TUI.Surfaces.Width (Item));

   function Aligned_Offset
     (Available : Natural;
      Used      : Natural;
      Alignment : Cross_Axis_Alignment) return Natural
   is
      Spare : constant Natural := Available - Natural'Min (Available, Used);
   begin
      case Alignment is
         when Start | Stretch => return 0;
         when Center          => return Spare / 2;
         when End_Aligned     => return Spare;
      end case;
   end Aligned_Offset;

   function Arrange
     (Items       : Surface_Array;
      Constraints : Constraint_Array;
      Width        : Natural;
      Height       : Natural;
      Flow         : Direction;
      Gap          : Natural := 0;
      Alignment    : Cross_Axis_Alignment := Stretch) return Layout_Result
   is
      Count : constant Natural := Items'Length;
      Result : Layout_Result (Count);
      Sizes : Size_Array (1 .. Count) := (others => 0);
      Major : constant Natural :=
        (if Flow = Horizontal then Width else Height);
      Gap_Count : constant Natural := (if Count = 0 then 0 else Count - 1);
      Actual_Gap : constant Natural :=
        (if Gap_Count = 0 then 0
         else Natural'Min (Gap, Major / Gap_Count));
      Available : Natural := Major - Actual_Gap * Gap_Count;
      Total_Weight : Natural := 0;
      Offset : Natural := 0;
   begin
      if Constraints'Length /= Count then
         raise Flyology_TUI.Components.Structure_Error with
           "box items and constraints have different lengths";
      elsif Height /= 0 and then Width > Natural'Last / Height then
         raise Flyology_TUI.Components.Capacity_Error with
           "box surface dimensions exceed addressable cell capacity";
      end if;

      Result.Frame_Value := Flyology_TUI.Surfaces.Create (Width, Height);

      --  Content and fixed requests receive space in declaration order.
      --  Fill requests share exactly the cells that remain.
      for Ordinal in 1 .. Count loop
         declare
            Item_Index : constant Positive :=
              Items'First + (Ordinal - 1);
            Constraint_Index : constant Positive :=
              Constraints'First + (Ordinal - 1);
            Rule : constant Constraint := Constraints (Constraint_Index);
            Requested : Natural := 0;
         begin
            case Rule.Kind is
               when Content =>
                  Requested := Intrinsic_Size (Items (Item_Index), Flow);
                  Sizes (Ordinal) := Natural'Min (Requested, Available);
                  Available := Available - Sizes (Ordinal);
               when Fixed =>
                  Requested := Rule.Cells;
                  Sizes (Ordinal) := Natural'Min (Requested, Available);
                  Available := Available - Sizes (Ordinal);
               when Fill =>
                  if Total_Weight > Natural'Last - Rule.Weight then
                     raise Flyology_TUI.Components.Capacity_Error with
                       "box fill weights exceed Natural";
                  end if;
                  Total_Weight := Total_Weight + Rule.Weight;
            end case;
         end;
      end loop;

      if Total_Weight > 0 then
         declare
            Remaining_Weight : Natural := Total_Weight;
         begin
            for Ordinal in 1 .. Count loop
               declare
                  Constraint_Index : constant Positive :=
                    Constraints'First + (Ordinal - 1);
                  Rule : constant Constraint :=
                    Constraints (Constraint_Index);
               begin
                  if Rule.Kind = Fill then
                     Sizes (Ordinal) := Natural
                       ((Long_Long_Integer (Available)
                         * Long_Long_Integer (Rule.Weight))
                        / Long_Long_Integer (Remaining_Weight));
                     Available := Available - Sizes (Ordinal);
                     Remaining_Weight := Remaining_Weight - Rule.Weight;
                  end if;
               end;
            end loop;
         end;
      end if;

      for Ordinal in 1 .. Count loop
         declare
            Item_Index : constant Positive :=
              Items'First + (Ordinal - 1);
            Child_Cross : constant Natural :=
              Intrinsic_Cross_Size (Items (Item_Index), Flow);
            Available_Cross : constant Natural :=
              (if Flow = Horizontal then Height else Width);
            Slot_Cross : constant Natural :=
              (if Alignment = Stretch
               then Available_Cross
               else Natural'Min (Child_Cross, Available_Cross));
            Cross_Offset : constant Natural :=
              Aligned_Offset (Available_Cross, Slot_Cross, Alignment);
            Area : constant Flyology_TUI.Geometry.Rectangle :=
              (if Flow = Horizontal
               then (X      => Integer (Offset),
                     Y      => Integer (Cross_Offset),
                     Width  => Sizes (Ordinal),
                     Height => Slot_Cross)
               else (X      => Integer (Cross_Offset),
                     Y      => Integer (Offset),
                     Width  => Slot_Cross,
                     Height => Sizes (Ordinal)));
         begin
            Result.Regions (Ordinal) := Area;
            if Area.Width > 0 and then Area.Height > 0 then
               declare
                  Slot : Flyology_TUI.Surfaces.Surface :=
                    Flyology_TUI.Surfaces.Create (Area.Width, Area.Height);
               begin
                  Slot.Overlay (Items (Item_Index), 0, 0);
                  Result.Frame_Value.Overlay
                    (Slot, Natural (Area.X), Natural (Area.Y));
               end;
            end if;

            Offset := Offset + Sizes (Ordinal);
            if Ordinal < Count then
               Offset := Offset + Actual_Gap;
            end if;
         end;
      end loop;

      return Result;
   end Arrange;

   function Horizontally
     (Items       : Surface_Array;
      Constraints : Constraint_Array;
      Width        : Natural;
      Height       : Natural;
      Gap          : Natural := 0;
      Alignment    : Cross_Axis_Alignment := Stretch) return Layout_Result
   is (Arrange
         (Items, Constraints, Width, Height, Horizontal, Gap, Alignment));

   function Vertically
     (Items       : Surface_Array;
      Constraints : Constraint_Array;
      Width        : Natural;
      Height       : Natural;
      Gap          : Natural := 0;
      Alignment    : Cross_Axis_Alignment := Stretch) return Layout_Result
   is (Arrange
         (Items, Constraints, Width, Height, Vertical, Gap, Alignment));

   function Frame
     (Item : Layout_Result) return Flyology_TUI.Surfaces.Surface
   is (Item.Frame_Value);

   function Region
     (Item  : Layout_Result;
      Index : Positive) return Flyology_TUI.Geometry.Rectangle
   is (Item.Regions (Index));

end Flyology_TUI.Layouts.Boxes;
