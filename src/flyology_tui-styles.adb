package body Flyology_TUI.Styles is

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

end Flyology_TUI.Styles;
