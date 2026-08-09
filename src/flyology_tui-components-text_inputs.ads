with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Events;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;

package Flyology_TUI.Components.Text_Inputs is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Model is tagged private;

   function Create
     (Width       : Positive := 30;
      Placeholder : Wide_Wide_String := "") return Model;

   procedure Set_Value (Item : in out Model; Value : Wide_Wide_String);
   function Value (Item : Model) return Wide_Wide_String;
   procedure Focus (Item : in out Model);
   procedure Blur (Item : in out Model);
   function Focused (Item : Model) return Boolean;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);

   function Render
     (Item                   : Model;
      Appearance             : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Placeholder_Appearance : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface;

   function Cursor_Column (Item : Model) return Natural;

private
   type Model is tagged record
      Content     : Text.Unbounded_Wide_Wide_String;
      Placeholder : Text.Unbounded_Wide_Wide_String;
      Cursor      : Natural := 0;
      Columns     : Positive := 30;
      Has_Focus   : Boolean := False;
   end record;
end Flyology_TUI.Components.Text_Inputs;
