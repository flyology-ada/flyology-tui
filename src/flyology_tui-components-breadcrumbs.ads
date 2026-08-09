with Ada.Containers.Vectors;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
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
package Flyology_TUI.Components.Breadcrumbs is
   type Item_Array is array (Positive range <>) of Item_Type;

   type Appearance is record
      Normal   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Active   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Separator : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Muted    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   function Create
     (Values        : Item_Array;
      Maximum_Width : Natural := Natural'Last;
      Enabled       : Boolean := True) return Model;
   procedure Set_Items (Item : in out Model; Values : Item_Array);
   procedure Set_Active (Item : in out Model; Id : Id_Type);
   procedure Set_Maximum_Width (Item : in out Model; Width : Natural);
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);

   function Length (Item : Model) return Natural;
   function Is_Empty (Item : Model) return Boolean;
   function Is_Enabled (Item : Model) return Boolean;
   function Width (Item : Model) return Natural;
   function Active_Id (Item : Model) return Id_Type
     with Pre => not Is_Empty (Item);
   function Focused_Id (Item : Model) return Id_Type
     with Pre => not Is_Empty (Item);
   function Is_Visible (Item : Model; Id : Id_Type) return Boolean;
   function Item_Region
     (Item : Model; Id : Id_Type) return Flyology_TUI.Geometry.Rectangle;

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
      Has_Focus : Boolean := False) return Flyology_TUI.Surfaces.Surface;
   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Flyology_TUI.Surfaces.Surface;

private
   package Item_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Item_Type);

   type Model is tagged record
      Values    : Item_Vectors.Vector;
      Active    : Natural := 0;
      Focused   : Natural := 0;
      Max_Width : Natural := Natural'Last;
      Enabled   : Boolean := True;
   end record;
end Flyology_TUI.Components.Breadcrumbs;
