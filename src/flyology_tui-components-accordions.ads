with Ada.Containers.Vectors;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

generic
   type Section_Type is private;
   type Id_Type is private;
   with function Id_Of (Section : Section_Type) return Id_Type;
   with function Label (Section : Section_Type) return Wide_Wide_String;
   with function "=" (Left, Right : Id_Type) return Boolean is <>;
   Capacity : Positive;
package Flyology_TUI.Components.Accordions is
   type Section_Array is array (Positive range <>) of Section_Type;
   type Expansion_Mode is (Single_Expansion, Multiple_Expansion);

   type Appearance is record
      Header          : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Expanded_Header : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Focused_Header  : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Disabled_Header : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Content          : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   function Create
     (Sections : Section_Array;
      Mode     : Expansion_Mode := Single_Expansion) return Model;

   --  Existing expansion, enabled, and focused state follows stable section
   --  ids. New sections are enabled and collapsed. A successful replacement
   --  cancels pending activation without relinquishing application-owned
   --  mouse capture before the matching release arrives.
   procedure Set_Sections
     (Item     : in out Model;
      Sections : Section_Array);

   function Length (Item : Model) return Natural;
   function Is_Empty (Item : Model) return Boolean;
   function Mode (Item : Model) return Expansion_Mode;

   function Contains (Item : Model; Id : Id_Type) return Boolean;
   function Is_Expanded (Item : Model; Id : Id_Type) return Boolean
     with Pre => Contains (Item, Id);
   function Is_Section_Enabled (Item : Model; Id : Id_Type) return Boolean
     with Pre => Contains (Item, Id);

   procedure Set_Expanded
     (Item     : in out Model;
      Id       : Id_Type;
      Expanded : Boolean := True);
   procedure Toggle (Item : in out Model; Id : Id_Type);
   procedure Collapse_All (Item : in out Model);
   procedure Expand_All (Item : in out Model)
     with Pre => Mode (Item) = Multiple_Expansion;

   procedure Set_Section_Enabled
     (Item    : in out Model;
      Id      : Id_Type;
      Enabled : Boolean := True);

   function Has_Focused_Section (Item : Model) return Boolean;
   function Focused_Id (Item : Model) return Id_Type
     with Pre => Has_Focused_Section (Item);

   type Body_Entry is record
      Id      : Id_Type;
      Content : Flyology_TUI.Surfaces.Surface;
   end record;
   type Body_Array is array (Positive range <>) of Body_Entry;

   --  Presentation owns only the composed frame, stable ids, and geometry.
   --  Bodies and themes are borrowed for this call and are never retained by
   --  Model. Bodies must contain exactly one entry for each expanded id.
   type Presentation is private;

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Presentation;

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Presentation;

   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface;

   function Has_Section
     (Item : Presentation;
      Id   : Id_Type) return Boolean;

   function Header_Region
     (Item : Presentation;
      Id   : Id_Type) return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Section (Item, Id);

   function Has_Body_Region
     (Item : Presentation;
      Id   : Id_Type) return Boolean;

   function Body_Region
     (Item : Presentation;
      Id   : Id_Type) return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Body_Region (Item, Id);

   function Render
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Look      : Appearance;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  Event coordinates are relative to Frame (Layout). Only header regions
   --  are consumed; body events remain available for caller-owned children.
   function Handle
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation)
      return Flyology_TUI.Components.Interactions.Update_Result;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);

   procedure Update
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation);

private
   package Section_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Section_Type);
   package Id_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Id_Type, "=" => "=");
   package Boolean_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Boolean);
   package Region_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Flyology_TUI.Geometry.Rectangle,
      "="          => Flyology_TUI.Geometry."=");

   type Model is tagged record
      Sections  : Section_Vectors.Vector;
      Expanded  : Boolean_Vectors.Vector;
      Enabled   : Boolean_Vectors.Vector;
      Kind      : Expansion_Mode := Single_Expansion;
      Focused   : Natural := 0;
      Armed     : Natural := 0;
      Capturing : Boolean := False;
   end record;

   type Presentation is record
      Frame_Value    : Flyology_TUI.Surfaces.Surface;
      Ids            : Id_Vectors.Vector;
      Header_Regions : Region_Vectors.Vector;
      Body_Regions   : Region_Vectors.Vector;
      Body_Visible   : Boolean_Vectors.Vector;
   end record;
end Flyology_TUI.Components.Accordions;
