generic
   type Sample_Type is private;
   Maximum_Capacity : Positive;
package Flyology_TUI.Numeric_Series is
   subtype Value_Type is Sample_Type;

   type Series is tagged private;

   --  Capacity is fixed at construction. Appending to a full series replaces
   --  the oldest sample; requesting more than Maximum_Capacity raises
   --  Components.Capacity_Error without constructing a partial value.
   function Create (Capacity : Positive := Maximum_Capacity) return Series;

   procedure Append (Item : in out Series; Value : Sample_Type);
   procedure Clear (Item : in out Series);

   function Length (Item : Series) return Natural;
   function Capacity (Item : Series) return Positive;
   function Is_Empty (Item : Series) return Boolean;

   --  Samples are indexed oldest to newest.
   function Element (Item : Series; Index : Positive) return Sample_Type
     with Pre => Index <= Length (Item);

private
   type Sample_Array is
     array (Natural range 0 .. Maximum_Capacity - 1) of Sample_Type;

   type Series is tagged record
      Values : Sample_Array;
      Limit  : Positive := Maximum_Capacity;
      Count  : Natural := 0;
      First  : Natural := 0;
   end record;
end Flyology_TUI.Numeric_Series;
