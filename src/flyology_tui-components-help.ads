with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;

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
end Flyology_TUI.Components.Help;
