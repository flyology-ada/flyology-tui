with Flyology_TUI.Colors;

package Flyology_TUI.Styles is
   type Style is record
      Foreground    : Flyology_TUI.Colors.Color := Flyology_TUI.Colors.Default;
      Background    : Flyology_TUI.Colors.Color := Flyology_TUI.Colors.Default;
      Bold          : Boolean := False;
      Faint         : Boolean := False;
      Italic        : Boolean := False;
      Underline     : Boolean := False;
      Blink         : Boolean := False;
      Reverse_Video : Boolean := False;
      Strikethrough : Boolean := False;
   end record;

   Default : constant Style := (others => <>);

   function With_Foreground
     (Item : Style;
      Color : Flyology_TUI.Colors.Color) return Style;

   function With_Background
     (Item : Style;
      Color : Flyology_TUI.Colors.Color) return Style;

   function Emphasized (Item : Style) return Style;
end Flyology_TUI.Styles;
