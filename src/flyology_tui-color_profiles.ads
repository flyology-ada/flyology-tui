with Flyology_TUI.Colors;

package Flyology_TUI.Color_Profiles is
   type Profile is (Monochrome, ANSI_16, ANSI_256, Truecolor);

   type Policy is
     (Automatic,
      Force_Monochrome,
      Force_ANSI_16,
      Force_ANSI_256,
      Force_Truecolor);

   --  Detect a conservative terminal profile from environment values supplied
   --  by a backend. NO_COLOR suppresses color only when it is both present and
   --  nonempty. This package never reads the process environment itself.
   function Detect
     (NO_Color_Present : Boolean;
      NO_Color_Value   : String;
      Color_Term       : String;
      Term             : String) return Profile;

   --  An explicit policy always takes precedence over backend detection.
   function Resolve
     (Requested : Policy;
      Detected  : Profile) return Profile;

   --  Adapt a source color to a terminal profile. Default colors stay default;
   --  monochrome drops only color while retaining other style attributes.
   function Adapt
     (Item   : Flyology_TUI.Colors.Color;
      Target : Profile) return Flyology_TUI.Colors.Color;
end Flyology_TUI.Color_Profiles;
