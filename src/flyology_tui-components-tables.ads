with Ada.Containers.Vectors;
with Ada.Strings.Wide_Wide_Unbounded;
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
   type Column_Id is (<>);
   with function Id_Of (Item : Item_Type) return Id_Type;
   with function Cell
     (Item : Item_Type; Column : Column_Id) return Wide_Wide_String;
   with function Less
     (Left, Right : Item_Type; Column : Column_Id) return Boolean;
   with function "=" (Left, Right : Id_Type) return Boolean is <>;
   Capacity : Positive;
package Flyology_TUI.Components.Tables is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Alignment is (Align_Left, Align_Center, Align_Right);
   type Sort_Direction is (Unsorted, Ascending, Descending);

   type Column_Definition is record
      Heading       : Text.Unbounded_Wide_Wide_String;
      Width         : Natural := 0;
      Minimum_Width : Natural := 0;
      Align         : Alignment := Align_Left;
      Sortable      : Boolean := False;
   end record;
   type Column_Definitions is array (Column_Id) of Column_Definition;
   type Item_Array is array (Positive range <>) of Item_Type;

   type Sort_Description is record
      Direction : Sort_Direction := Unsorted;
      Column    : Column_Id := Column_Id'First;
   end record;

   type Appearance is record
      Header   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Normal   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selected : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Muted    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Divider  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   function Create
     (Values        : Item_Array;
      Columns       : Column_Definitions;
      Viewport_Rows : Natural := 8;
      Enabled       : Boolean := True) return Model;

   --  Replacement validates capacity and identity before mutating the model.
   --  A surviving selected ID remains selected after replacement or sorting.
   procedure Set_Rows (Item : in out Model; Values : Item_Array);
   procedure Set_Columns
     (Item : in out Model; Columns : Column_Definitions);
   procedure Set_Viewport_Rows (Item : in out Model; Rows : Natural);
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);

   procedure Sort_By
     (Item      : in out Model;
      Column    : Column_Id;
      Direction : Sort_Direction);
   function Sort (Item : Model) return Sort_Description;

   procedure Select_Id (Item : in out Model; Id : Id_Type);
   procedure Clear_Selection (Item : in out Model);
   function Has_Selection (Item : Model) return Boolean;
   function Selected_Id (Item : Model) return Id_Type
     with Pre => Has_Selection (Item);
   function Focused_Id (Item : Model) return Id_Type
     with Pre => Length (Item) > 0;

   function Length (Item : Model) return Natural;
   function Is_Empty (Item : Model) return Boolean;
   function Is_Enabled (Item : Model) return Boolean;
   function Viewport_Rows (Item : Model) return Natural;
   function First_Visible_Row (Item : Model) return Natural;
   function Visible_Row_Count (Item : Model) return Natural;
   function Row_Id
     (Item : Model; Display_Position : Positive) return Id_Type
     with Pre => Display_Position <= Length (Item);
   function Visible_Row_Id
     (Item : Model; Visible_Position : Positive) return Id_Type
     with Pre => Visible_Position <= Visible_Row_Count (Item);

   function Width (Item : Model) return Natural;
   function Height (Item : Model) return Natural;
   function Header_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle;
   function Column_Region
     (Item : Model; Column : Column_Id) return Flyology_TUI.Geometry.Rectangle;
   function Visible_Row_Region
     (Item : Model; Visible_Position : Positive)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Visible_Position <= Viewport_Rows (Item);

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
   package Index_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Natural);

   type Model is tagged record
      Values       : Item_Vectors.Vector;
      Order        : Index_Vectors.Vector;
      Definitions  : Column_Definitions;
      Sorting      : Sort_Description;
      Selected     : Natural := 0;
      Focused      : Natural := 0;
      First        : Natural := 0;
      Rows         : Natural := 8;
      Enabled      : Boolean := True;
   end record;
end Flyology_TUI.Components.Tables;
