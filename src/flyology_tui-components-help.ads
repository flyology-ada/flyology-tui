with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Help is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Binding is record
      Key         : Text.Unbounded_Wide_Wide_String;
      Description : Text.Unbounded_Wide_Wide_String;
      Enabled     : Boolean := True;
   end record;

   type Binding_Array is array (Positive range <>) of Binding;

   function Render
     (Bindings          : Binding_Array;
      Width             : Positive;
      Vertical          : Boolean := True;
      Key_Appearance    : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Detail_Appearance : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface;

   --  Render keys with Primary and descriptions with Muted.
   function Render
     (Bindings : Binding_Array;
      Width    : Positive;
      Theme    : Flyology_TUI.Themes.Theme;
      Vertical : Boolean := True)
      return Flyology_TUI.Surfaces.Surface;
end Flyology_TUI.Components.Help;
