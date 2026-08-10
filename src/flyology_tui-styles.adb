package body Flyology_TUI.Styles is
   use type Flyology_TUI.Colors.Color_Kind;

   function With_Foreground
     (Item : Style;
      Color : Flyology_TUI.Colors.Color) return Style
   is
      Result : Style := Item;
   begin
      Result.Foreground := Color;
      return Result;
   end With_Foreground;

   function With_Background
     (Item : Style;
      Color : Flyology_TUI.Colors.Color) return Style
   is
      Result : Style := Item;
   begin
      Result.Background := Color;
      return Result;
   end With_Background;

   function Emphasized (Item : Style) return Style is
      Result : Style := Item;
   begin
      Result.Bold := True;
      return Result;
   end Emphasized;

   function Inherit_Colors (Item, Parent : Style) return Style is
      Result : Style := Item;
   begin
      if Result.Foreground.Kind = Flyology_TUI.Colors.Default_Color then
         Result.Foreground := Parent.Foreground;
      end if;
      if Result.Background.Kind = Flyology_TUI.Colors.Default_Color then
         Result.Background := Parent.Background;
      end if;
      return Result;
   end Inherit_Colors;

end Flyology_TUI.Styles;
