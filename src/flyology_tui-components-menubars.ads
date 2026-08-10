with Ada.Containers.Vectors;
with Interfaces;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

generic
   type Menu_Id is private;
   type Item_Id is private;
   with function Menu_Label (Id : Menu_Id) return Wide_Wide_String;
   with function Item_Label (Id : Item_Id) return Wide_Wide_String;
   with function Shortcut_Label (Id : Item_Id) return Wide_Wide_String;
   with function Menu_Mnemonic
     (Id : Menu_Id) return Wide_Wide_Character;
   with function Item_Mnemonic
     (Id : Item_Id) return Wide_Wide_Character;
   with function "=" (Left, Right : Menu_Id) return Boolean is <>;
   with function "=" (Left, Right : Item_Id) return Boolean is <>;
   Maximum_Menus : Positive;
   Maximum_Items : Positive;
   Maximum_Depth : Positive;
package Flyology_TUI.Components.Menubars is
   type Menu_Definition is record
      Id        : Menu_Id;
      Top_Level : Boolean := True;
      Enabled   : Boolean := True;
   end record;
   type Menu_Array is array (Positive range <>) of Menu_Definition;

   type Item_Kind is
     (Action_Item, Check_Item, Radio_Item, Submenu_Item, Separator_Item);
   type Item_Definition (Kind : Item_Kind := Action_Item) is record
      Id      : Item_Id;
      Menu    : Menu_Id;
      Enabled : Boolean := True;
      case Kind is
         when Action_Item | Separator_Item => null;
         when Check_Item =>
            Checked : Boolean := False;
         when Radio_Item =>
            Group    : Item_Id;
            Selected : Boolean := False;
         when Submenu_Item =>
            Child : Menu_Id;
      end case;
   end record;
   type Item_Array is array (Positive range <>) of Item_Definition;

   function Action
     (Id : Item_Id; Menu : Menu_Id; Enabled : Boolean := True)
      return Item_Definition;
   function Separator (Id : Item_Id; Menu : Menu_Id) return Item_Definition;
   function Check
     (Id      : Item_Id;
      Menu    : Menu_Id;
      Checked : Boolean := False;
      Enabled : Boolean := True) return Item_Definition;
   function Radio
     (Id       : Item_Id;
      Menu     : Menu_Id;
      Group    : Item_Id;
      Selected : Boolean := False;
      Enabled  : Boolean := True) return Item_Definition;
   function Submenu
     (Id      : Item_Id;
      Menu    : Menu_Id;
      Child   : Menu_Id;
      Enabled : Boolean := True) return Item_Definition;

   type Appearance is record
      Bar         : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Menu        : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Highlighted : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Disabled    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Separator   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Shortcut    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Marker      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Result_Kind is
     (No_Result, Action_Activated, Check_Changed, Radio_Changed);
   type Update_Result (Kind : Result_Kind := No_Result) is private;

   type Model is tagged private;

   function Create
     (Menus : Menu_Array; Items : Item_Array; Enabled : Boolean := True)
      return Model;

   --  Replacement validates capacities, ids, references, radio selections,
   --  cycles, and Maximum_Depth before mutation. Mutable enabled, check/radio,
   --  focus, and open-path state follow stable ids. Pending activation is
   --  cancelled while capture ownership survives until the matching
   --  left-button release.
   procedure Set_Content
     (Item : in out Model; Menus : Menu_Array; Items : Item_Array);

   function Menu_Count (Item : Model) return Natural;
   function Item_Count (Item : Model) return Natural;
   function Contains_Menu (Item : Model; Id : Menu_Id) return Boolean;
   function Contains_Item (Item : Model; Id : Item_Id) return Boolean;
   function Is_Enabled (Item : Model) return Boolean;
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);
   procedure Set_Menu_Enabled
     (Item : in out Model; Id : Menu_Id; Enabled : Boolean := True);
   procedure Set_Item_Enabled
     (Item : in out Model; Id : Item_Id; Enabled : Boolean := True);

   function Is_Open (Item : Model) return Boolean;
   function Open_Depth (Item : Model) return Natural;
   procedure Open_Menu (Item : in out Model; Id : Menu_Id);
   procedure Close (Item : in out Model);
   function Dismiss (Item : in out Model) return Update_Result;

   function Has_Focused_Menu (Item : Model) return Boolean;
   function Focused_Menu (Item : Model) return Menu_Id
     with Pre => Has_Focused_Menu (Item);
   function Has_Highlighted_Item (Item : Model) return Boolean;
   function Highlighted_Item (Item : Model) return Item_Id
     with Pre => Has_Highlighted_Item (Item);

   function Is_Checked (Item : Model; Id : Item_Id) return Boolean
     with Pre => Contains_Item (Item, Id);
   procedure Set_Checked
     (Item : in out Model; Id : Item_Id; Checked : Boolean := True);

   function Interaction
     (Item : Update_Result)
      return Flyology_TUI.Components.Interactions.Update_Result;
   function Activated_Menu (Item : Update_Result) return Menu_Id
     with Pre => Item.Kind /= No_Result;
   function Activated_Item (Item : Update_Result) return Item_Id
     with Pre => Item.Kind /= No_Result;
   function Checked_Value (Item : Update_Result) return Boolean
     with Pre => Item.Kind = Check_Changed;
   function Radio_Group (Item : Update_Result) return Item_Id
     with Pre => Item.Kind = Radio_Changed;

   type Presentation is private;

   --  Width and Height are the complete overlay viewport. X and Y are signed
   --  menubar origins inside it. Frame and all queried regions are clipped to
   --  that viewport; Presentation retains no theme or callback.
   function Present
     (Item      : Model;
      Width     : Natural;
      Height    : Natural;
      X         : Integer;
      Y         : Integer;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Presentation;
   function Present
     (Item      : Model;
      Width     : Natural;
      Height    : Natural;
      X         : Integer;
      Y         : Integer;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Presentation;

   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface;
   function Bar_Region
     (Item : Presentation) return Flyology_TUI.Geometry.Rectangle;
   function Has_Menu_Region
     (Item : Presentation; Id : Menu_Id) return Boolean;
   function Menu_Region
     (Item : Presentation; Id : Menu_Id)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Menu_Region (Item, Id);
   function Has_Item_Region
     (Item : Presentation; Id : Item_Id) return Boolean;
   function Item_Region
     (Item : Presentation; Id : Item_Id)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Item_Region (Item, Id);

   function Render
     (Item      : Model;
      Width     : Natural;
      Height    : Natural;
      X         : Integer;
      Y         : Integer;
      Look      : Appearance;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface;
   function Render
     (Item      : Model;
      Width     : Natural;
      Height    : Natural;
      X         : Integer;
      Y         : Integer;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface;

   function Handle
     (Item : in out Model; Event : Flyology_TUI.Events.Terminal_Event)
      return Update_Result;
   --  Event coordinates are local to Presentation.Frame. Any presentation
   --  predating a render- or routing-affecting mutation is rejected. A
   --  matching captured left release always relinquishes application capture;
   --  it activates only when no mutation invalidated the original press.
   function Handle
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation) return Update_Result;

private
   subtype Revision_Number is Interfaces.Unsigned_64;
   type Stored_Item is record
      Kind    : Item_Kind := Action_Item;
      Id      : Item_Id;
      Menu    : Menu_Id;
      Enabled : Boolean := True;
      State   : Boolean := False;
      Group   : Item_Id;
      Child   : Menu_Id;
   end record;

   package Menu_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Menu_Definition);
   package Item_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Stored_Item);
   package Boolean_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Boolean);
   package Natural_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Natural);

   type Model is tagged record
      Menus       : Menu_Vectors.Vector;
      Items       : Item_Vectors.Vector;
      Item_State  : Boolean_Vectors.Vector;
      Open_Menus  : Natural_Vectors.Vector;
      Highlights  : Natural_Vectors.Vector;
      Focused     : Natural := 0;
      Armed_Menu  : Natural := 0;
      Armed_Item  : Natural := 0;
      Capturing   : Boolean := False;
      Enabled     : Boolean := True;
      Presentation_Revision   : Revision_Number := 0;
      Capture_Layout_Revision : Revision_Number := 0;
      Capture_State_Revision  : Revision_Number := 0;
   end record;

   type Update_Result (Kind : Result_Kind := No_Result) is record
      Event : Flyology_TUI.Components.Interactions.Update_Result;
      case Kind is
         when No_Result => null;
         when Action_Activated =>
            Action_Menu : Menu_Id;
            Action_Id   : Item_Id;
         when Check_Changed =>
            Check_Menu : Menu_Id;
            Check_Id   : Item_Id;
            Is_Checked : Boolean;
         when Radio_Changed =>
            Radio_Menu : Menu_Id;
            Radio_Id   : Item_Id;
            Group_Id   : Item_Id;
      end case;
   end record;

   type Menu_Hit is record
      Id     : Menu_Id;
      Index  : Natural := 0;
      Depth  : Natural := 0;
      Region : Flyology_TUI.Geometry.Rectangle;
   end record;
   package Menu_Hit_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Menu_Hit);

   type Item_Hit is record
      Id     : Item_Id;
      Index  : Natural := 0;
      Depth  : Positive := 1;
      Region : Flyology_TUI.Geometry.Rectangle;
   end record;
   package Item_Hit_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Item_Hit);

   type Presentation is record
      Frame_Value : Flyology_TUI.Surfaces.Surface;
      Bar_Value   : Flyology_TUI.Geometry.Rectangle;
      Menus       : Menu_Hit_Vectors.Vector;
      Items       : Item_Hit_Vectors.Vector;
      Revision    : Revision_Number := 0;
   end record;
end Flyology_TUI.Components.Menubars;
