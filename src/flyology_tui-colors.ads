package Flyology_TUI.Colors is
   type ANSI_Color is
     (Black,
      Red,
      Green,
      Yellow,
      Blue,
      Magenta,
      Cyan,
      White,
      Bright_Black,
      Bright_Red,
      Bright_Green,
      Bright_Yellow,
      Bright_Blue,
      Bright_Magenta,
      Bright_Cyan,
      Bright_White);

   type Color_Kind is (Default_Color, ANSI, Indexed, RGB);
   subtype Channel is Natural range 0 .. 255;

   type Color (Kind : Color_Kind := Default_Color) is record
      case Kind is
         when Default_Color =>
            null;
         when ANSI =>
            Name : ANSI_Color := White;
         when Indexed =>
            Index : Channel := 0;
         when RGB =>
            Red_Value   : Channel := 0;
            Green_Value : Channel := 0;
            Blue_Value  : Channel := 0;
      end case;
   end record;

   Default : constant Color := (Kind => Default_Color);

   function Basic (Name : ANSI_Color) return Color is
     (Kind => ANSI, Name => Name);

   function Palette (Index : Channel) return Color is
     (Kind => Indexed, Index => Index);

   function True_Color
     (Red, Green, Blue : Channel) return Color
   is (Kind        => RGB,
       Red_Value   => Red,
       Green_Value => Green,
       Blue_Value  => Blue);
end Flyology_TUI.Colors;
