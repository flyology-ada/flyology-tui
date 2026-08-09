with Ada.Containers.Vectors;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

generic
   type Item_Type is private;
   type Id_Type is private;
   with function Id_Of (Item : Item_Type) return Id_Type;
   with function Label (Item : Item_Type) return Wide_Wide_String;
   with function "=" (Left, Right : Id_Type) return Boolean is <>;
   Capacity : Positive;
package Flyology_TUI.Components.Selectors is
   type Item_Array is array (Positive range <>) of Item_Type;
   type Id_Array is array (Positive range <>) of Id_Type;

   type Appearance is record
      Normal   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selected : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Disabled : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   function Create
     (Values  : Item_Array;
      Mode    : Flyology_TUI.Components.Selection_Mode :=
        Flyology_TUI.Components.Single_Selection;
      Enabled : Boolean := True) return Model;

   procedure Set_Items (Item : in out Model; Values : Item_Array);
   procedure Replace_Selection (Item : in out Model; Values : Id_Array);
   procedure Set_Selected
     (Item : in out Model;
      Id   : Id_Type;
      Value : Boolean := True);

   function Length (Item : Model) return Natural;
   function Is_Empty (Item : Model) return Boolean;
   function Selected_Count (Item : Model) return Natural;
   function Is_Selected (Item : Model; Id : Id_Type) return Boolean;
   function Mode (Item : Model)
      return Flyology_TUI.Components.Selection_Mode;

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);
   function Is_Enabled (Item : Model) return Boolean;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event);

   function Render
     (Item      : Model;
      Look      : Appearance;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface;

private
   package Item_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Item_Type);
   package Boolean_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Boolean);

   type Model is tagged record
      Values   : Item_Vectors.Vector;
      Selected : Boolean_Vectors.Vector;
      Kind     : Flyology_TUI.Components.Selection_Mode :=
        Flyology_TUI.Components.Single_Selection;
      Focused  : Natural := 0;
      Armed    : Natural := 0;
      Enabled  : Boolean := True;
   end record;
end Flyology_TUI.Components.Selectors;
