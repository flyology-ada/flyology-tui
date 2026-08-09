with Ada.Characters.Handling;
with Ada.Strings.Fixed;

package body Flyology_TUI.Color_Profiles is
   use type Flyology_TUI.Colors.Color_Kind;

   type RGB_Value is record
      Red, Green, Blue : Flyology_TUI.Colors.Channel;
   end record;

   Cube_Levels : constant array (Natural range 0 .. 5)
     of Flyology_TUI.Colors.Channel := (0, 95, 135, 175, 215, 255);

   function ANSI_Value
     (Name : Flyology_TUI.Colors.ANSI_Color) return RGB_Value
   is
   begin
      return
        (case Name is
            when Flyology_TUI.Colors.Black          => (0, 0, 0),
            when Flyology_TUI.Colors.Red            => (128, 0, 0),
            when Flyology_TUI.Colors.Green          => (0, 128, 0),
            when Flyology_TUI.Colors.Yellow         => (128, 128, 0),
            when Flyology_TUI.Colors.Blue           => (0, 0, 128),
            when Flyology_TUI.Colors.Magenta        => (128, 0, 128),
            when Flyology_TUI.Colors.Cyan           => (0, 128, 128),
            when Flyology_TUI.Colors.White          => (192, 192, 192),
            when Flyology_TUI.Colors.Bright_Black   => (128, 128, 128),
            when Flyology_TUI.Colors.Bright_Red     => (255, 0, 0),
            when Flyology_TUI.Colors.Bright_Green   => (0, 255, 0),
            when Flyology_TUI.Colors.Bright_Yellow  => (255, 255, 0),
            when Flyology_TUI.Colors.Bright_Blue    => (0, 0, 255),
            when Flyology_TUI.Colors.Bright_Magenta => (255, 0, 255),
            when Flyology_TUI.Colors.Bright_Cyan    => (0, 255, 255),
            when Flyology_TUI.Colors.Bright_White   => (255, 255, 255));
   end ANSI_Value;

   function Indexed_Value
     (Index : Flyology_TUI.Colors.Channel) return RGB_Value
   is
      Offset : Natural;
      Level  : Natural;
   begin
      if Index < 16 then
         return ANSI_Value
           (Flyology_TUI.Colors.ANSI_Color'Val (Natural (Index)));
      elsif Index < 232 then
         Offset := Natural (Index) - 16;
         return
           (Red   => Cube_Levels (Offset / 36),
            Green => Cube_Levels ((Offset / 6) mod 6),
            Blue  => Cube_Levels (Offset mod 6));
      else
         Level := 8 + 10 * (Natural (Index) - 232);
         return (others => Flyology_TUI.Colors.Channel (Level));
      end if;
   end Indexed_Value;

   function Squared_Distance (Left, Right : RGB_Value) return Natural is
      Red_Difference   : constant Integer :=
        Integer (Left.Red) - Integer (Right.Red);
      Green_Difference : constant Integer :=
        Integer (Left.Green) - Integer (Right.Green);
      Blue_Difference  : constant Integer :=
        Integer (Left.Blue) - Integer (Right.Blue);
   begin
      return
        Natural
          (Red_Difference * Red_Difference
           + Green_Difference * Green_Difference
           + Blue_Difference * Blue_Difference);
   end Squared_Distance;

   function Nearest_ANSI
     (Value : RGB_Value) return Flyology_TUI.Colors.ANSI_Color
   is
      Best          : Flyology_TUI.Colors.ANSI_Color :=
        Flyology_TUI.Colors.Black;
      Best_Distance : Natural := Natural'Last;
   begin
      for Candidate in Flyology_TUI.Colors.ANSI_Color loop
         declare
            Distance : constant Natural :=
              Squared_Distance (Value, ANSI_Value (Candidate));
         begin
            --  Enumeration order is palette order, so strict comparison gives
            --  the lower palette entry deterministic precedence on a tie.
            if Distance < Best_Distance then
               Best := Candidate;
               Best_Distance := Distance;
            end if;
         end;
      end loop;
      return Best;
   end Nearest_ANSI;

   function Nearest_Indexed
     (Value : RGB_Value) return Flyology_TUI.Colors.Channel
   is
      Best          : Flyology_TUI.Colors.Channel := 0;
      Best_Distance : Natural := Natural'Last;
   begin
      for Candidate in Flyology_TUI.Colors.Channel loop
         declare
            Distance : constant Natural :=
              Squared_Distance (Value, Indexed_Value (Candidate));
         begin
            --  Ascending scan plus strict comparison chooses the lower index
            --  for duplicate and equidistant palette entries.
            if Distance < Best_Distance then
               Best := Candidate;
               Best_Distance := Distance;
            end if;
         end;
      end loop;
      return Best;
   end Nearest_Indexed;

   function Detect
     (NO_Color_Present : Boolean;
      NO_Color_Value   : String;
      Color_Term       : String;
      Term             : String) return Profile
   is
      Lower_Color_Term : constant String :=
        Ada.Characters.Handling.To_Lower (Color_Term);
      Lower_Term : constant String :=
        Ada.Characters.Handling.To_Lower (Term);
      function Contains (Source, Pattern : String) return Boolean is
        (Ada.Strings.Fixed.Index (Source, Pattern) /= 0);
   begin
      if NO_Color_Present and then NO_Color_Value'Length > 0 then
         return Monochrome;
      elsif Contains (Lower_Color_Term, "truecolor")
        or else Contains (Lower_Color_Term, "24bit")
        or else Contains (Lower_Term, "truecolor")
        or else Contains (Lower_Term, "24bit")
        or else Contains (Lower_Term, "direct")
      then
         return Truecolor;
      elsif Contains (Lower_Term, "256color") then
         return ANSI_256;
      elsif Lower_Term'Length = 0 or else Lower_Term = "dumb" then
         return Monochrome;
      else
         return ANSI_16;
      end if;
   end Detect;

   function Resolve
     (Requested : Policy;
      Detected  : Profile) return Profile
   is
   begin
      return
        (case Requested is
            when Automatic        => Detected,
            when Force_Monochrome => Monochrome,
            when Force_ANSI_16    => ANSI_16,
            when Force_ANSI_256   => ANSI_256,
            when Force_Truecolor  => Truecolor);
   end Resolve;

   function Adapt
     (Item   : Flyology_TUI.Colors.Color;
      Target : Profile) return Flyology_TUI.Colors.Color
   is
      Value : RGB_Value;
   begin
      if Item.Kind = Flyology_TUI.Colors.Default_Color
        or else Target = Monochrome
      then
         return Flyology_TUI.Colors.Default;
      elsif Item.Kind = Flyology_TUI.Colors.ANSI then
         return Item;
      elsif Target = Truecolor
        or else (Target = ANSI_256
                 and then Item.Kind = Flyology_TUI.Colors.Indexed)
      then
         return Item;
      end if;

      case Item.Kind is
         when Flyology_TUI.Colors.Default_Color |
              Flyology_TUI.Colors.ANSI =>
            raise Program_Error;
         when Flyology_TUI.Colors.Indexed =>
            Value := Indexed_Value (Item.Index);
         when Flyology_TUI.Colors.RGB =>
            Value :=
              (Item.Red_Value, Item.Green_Value, Item.Blue_Value);
      end case;

      case Target is
         when Monochrome | Truecolor =>
            raise Program_Error;
         when ANSI_16 =>
            return Flyology_TUI.Colors.Basic (Nearest_ANSI (Value));
         when ANSI_256 =>
            return Flyology_TUI.Colors.Palette (Nearest_Indexed (Value));
      end case;
   end Adapt;
end Flyology_TUI.Color_Profiles;
