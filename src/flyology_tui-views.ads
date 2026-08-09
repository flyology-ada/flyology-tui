with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;

package Flyology_TUI.Views is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Mouse_Mode is
     (Mouse_Disabled,
      Button_Events,
      Cell_Motion,
      All_Motion);
   type Cursor_Shape is
     (Cursor_Block, Cursor_Underline, Cursor_Bar);

   type Cursor_Description is record
      Visible : Boolean := False;
      X       : Natural := 0;
      Y       : Natural := 0;
      Shape   : Cursor_Shape := Cursor_Block;
      Blink   : Boolean := True;
   end record;

   --  A complete declaration of the desired terminal view. Backends reconcile
   --  these fields with terminal state and must restore any enabled modes when
   --  they close, including after an exception.
   type View is tagged record
      Frame             : Flyology_TUI.Surfaces.Surface;
      Alternate_Screen  : Boolean := False;
      Mouse             : Mouse_Mode := Mouse_Disabled;
      Report_Focus      : Boolean := False;
      Bracketed_Paste   : Boolean := True;
      Window_Title      : Text.Unbounded_Wide_Wide_String;
      Cursor            : Cursor_Description;
   end record;

   function Plain (Content : Wide_Wide_String) return View;

   function Styled
     (Content    : Wide_Wide_String;
      Appearance : Flyology_TUI.Styles.Style) return View;

   function From_Surface (Frame : Flyology_TUI.Surfaces.Surface) return View;
end Flyology_TUI.Views;
