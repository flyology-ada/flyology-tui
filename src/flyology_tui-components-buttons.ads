with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Buttons is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Appearance is record
      Normal   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Pressed  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Disabled : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   function Create
     (Label   : Wide_Wide_String;
      Enabled : Boolean := True) return Model;

   procedure Set_Label (Item : in out Model; Label : Wide_Wide_String);
   function Label (Item : Model) return Wide_Wide_String;
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);
   function Is_Enabled (Item : Model) return Boolean;
   function Is_Armed (Item : Model) return Boolean;
   function Width (Item : Model) return Natural;

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
     (Item       : Model;
      Look       : Appearance;
      Has_Focus  : Boolean := False)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item       : Model;
      Theme      : Flyology_TUI.Themes.Theme;
      Has_Focus  : Boolean := False)
      return Flyology_TUI.Surfaces.Surface;

private
   type Model is tagged record
      Caption : Text.Unbounded_Wide_Wide_String;
      Enabled : Boolean := True;
      Armed   : Boolean := False;
      Capturing : Boolean := False;
   end record;
end Flyology_TUI.Components.Buttons;
