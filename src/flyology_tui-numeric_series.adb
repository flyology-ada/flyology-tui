with Flyology_TUI.Components;

package body Flyology_TUI.Numeric_Series is

   function Wrapped_Position
     (First, Offset : Natural;
      Limit         : Positive) return Natural
   is
      Until_End : constant Positive := Limit - First;
   begin
      if Offset >= Until_End then
         return Offset - Until_End;
      else
         return First + Offset;
      end if;
   end Wrapped_Position;

   function Create (Capacity : Positive := Maximum_Capacity) return Series is
   begin
      if Capacity > Maximum_Capacity then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      return (Limit => Capacity, others => <>);
   end Create;

   procedure Append (Item : in out Series; Value : Sample_Type) is
      Position : Natural;
   begin
      if Item.Count < Item.Limit then
         Position := Wrapped_Position (Item.First, Item.Count, Item.Limit);
         Item.Values (Position) := Value;
         Item.Count := Item.Count + 1;
      else
         Item.Values (Item.First) := Value;
         Item.First :=
           (if Item.First = Item.Limit - 1 then 0 else Item.First + 1);
      end if;
   end Append;

   procedure Clear (Item : in out Series) is
   begin
      Item.Count := 0;
      Item.First := 0;
   end Clear;

   function Length (Item : Series) return Natural is (Item.Count);
   function Capacity (Item : Series) return Positive is (Item.Limit);
   function Is_Empty (Item : Series) return Boolean is (Item.Count = 0);

   function Element (Item : Series; Index : Positive) return Sample_Type is
     (Item.Values
        (Wrapped_Position (Item.First, Index - 1, Item.Limit)));

end Flyology_TUI.Numeric_Series;
