with Ada.Containers.Vectors;
with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Events;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;

generic
   type Item_Type is private;
   with function Label (Item : Item_Type) return Wide_Wide_String;
package Flyology_TUI.Components.Lists is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Item_Array is array (Positive range <>) of Item_Type;
   type Model is tagged private;

   function Create (Width, Height : Positive) return Model;
   procedure Set_Items (Item : in out Model; Values : Item_Array);
   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);

   function Is_Empty (Item : Model) return Boolean;
   function Selected_Index (Item : Model) return Natural;
   function Selected_Item (Item : Model) return Item_Type
     with Pre => not Is_Empty (Item);

   function Render
     (Item                : Model;
      Appearance          : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Selected_Appearance : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface;

private
   package Item_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Item_Type);

   type Model is tagged record
      Values   : Item_Vectors.Vector;
      Selected : Natural := 0;
      Offset   : Natural := 0;
      Columns  : Positive := 1;
      Rows     : Positive := 1;
   end record;
end Flyology_TUI.Components.Lists;
