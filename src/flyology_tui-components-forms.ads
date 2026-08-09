with Ada.Containers.Vectors;
with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Components.Text_Inputs;
with Flyology_TUI.Events;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Forms is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Field_Definition is record
      Label       : Text.Unbounded_Wide_Wide_String;
      Initial     : Text.Unbounded_Wide_Wide_String;
      Placeholder : Text.Unbounded_Wide_Wide_String;
   end record;

   type Field_Array is array (Positive range <>) of Field_Definition;
   type Model is tagged private;

   function Create
     (Fields      : Field_Array;
      Input_Width : Positive := 30) return Model;

   --  Mouse coordinates are relative to Render. A local left-click selects a
   --  field and places its text cursor when the input cells are clicked.
   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);

   function Submitted (Item : Model) return Boolean;
   function Cancelled (Item : Model) return Boolean;
   procedure Reset_Status (Item : in out Model);

   function Field_Count (Item : Model) return Natural;
   function Field_Value (Item : Model; Index : Positive)
      return Wide_Wide_String
     with Pre => Index <= Field_Count (Item);

   --  Return the active input cursor position relative to Render. Empty forms
   --  return (0, 0).
   procedure Cursor_Position
     (Item : Model;
      X, Y : out Natural);

   function Render
     (Item                : Model;
      Label_Appearance    : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Input_Appearance    : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Focused_Appearance  : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface;

   --  Render labels with Muted, inputs with Input, and the active input with
   --  Focused.
   function Render
     (Item  : Model;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

private
   type Field is record
      Label : Text.Unbounded_Wide_Wide_String;
      Input : Flyology_TUI.Components.Text_Inputs.Model;
   end record;

   package Field_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Field);

   type Model is tagged record
      Fields       : Field_Vectors.Vector;
      Active       : Natural := 0;
      Was_Submitted : Boolean := False;
      Was_Cancelled : Boolean := False;
   end record;
end Flyology_TUI.Components.Forms;
