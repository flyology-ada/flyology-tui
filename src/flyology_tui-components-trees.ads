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
   with function Depth_Of (Item : Item_Type) return Natural;
   with function "=" (Left, Right : Id_Type) return Boolean is <>;
   Capacity : Positive;
package Flyology_TUI.Components.Trees is
   type Item_Array is array (Positive range <>) of Item_Type;

   type Appearance is record
      Normal     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selected   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Muted      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Disclosure : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   function Create
     (Values        : Item_Array;
      Viewport_Rows : Natural := 8;
      Enabled       : Boolean := True) return Model;

   --  Nodes are a flat preorder sequence. The first depth must be zero and a
   --  depth may increase by at most one. Validation is atomic.
   procedure Set_Nodes (Item : in out Model; Values : Item_Array);
   --  Collapsing a node whose descendant is selected moves selection to the
   --  collapsed node. Descendant expansion flags remain available on reopen.
   procedure Set_Expanded
     (Item : in out Model; Id : Id_Type; Expanded : Boolean := True);
   function Is_Expanded (Item : Model; Id : Id_Type) return Boolean;
   procedure Select_Id (Item : in out Model; Id : Id_Type);
   procedure Set_Viewport_Rows (Item : in out Model; Rows : Natural);
   procedure Set_Maximum_Width (Item : in out Model; Width : Natural);
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);

   function Length (Item : Model) return Natural;
   function Visible_Length (Item : Model) return Natural;
   function Is_Empty (Item : Model) return Boolean;
   function Is_Enabled (Item : Model) return Boolean;
   function Viewport_Rows (Item : Model) return Natural;
   function Width (Item : Model) return Natural;
   function Height (Item : Model) return Natural;
   function First_Visible_Row (Item : Model) return Natural;
   function Visible_Row_Count (Item : Model) return Natural;
   function Selected_Id (Item : Model) return Id_Type
     with Pre => not Is_Empty (Item);
   function Visible_Id
     (Item : Model; Position : Positive) return Id_Type
     with Pre => Position <= Visible_Length (Item);
   function Visible_Row_Region
     (Item : Model; Position : Positive) return Flyology_TUI.Geometry.Rectangle
     with Pre => Position <= Viewport_Rows (Item);
   function Disclosure_Region
     (Item : Model; Visible_Position : Positive)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Visible_Position <= Visible_Row_Count (Item);

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
   package Boolean_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Boolean);

   type Model is tagged record
      Values      : Item_Vectors.Vector;
      Expanded    : Boolean_Vectors.Vector;
      Selected    : Natural := 0;
      First       : Natural := 0;
      Rows        : Natural := 8;
      Max_Width   : Natural := Natural'Last;
      Enabled     : Boolean := True;
   end record;
end Flyology_TUI.Components.Trees;
