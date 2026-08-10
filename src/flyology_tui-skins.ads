with Flyology_TUI.Colors;
with Flyology_TUI.Styles;
with Flyology_TUI.Themes;

package Flyology_TUI.Skins is
   --  A Skin is a borrowed render-time visual language. It combines semantic
   --  colors with structural chrome while component models retain neither.
   type Skin_Id is
     (Charm_Default, Charm_Dark, Charm_Light, Turbo_Vision);

   type Border_Glyphs is record
      Top_Left     : Wide_Wide_Character := '+';
      Horizontal   : Wide_Wide_Character := '-';
      Top_Right    : Wide_Wide_Character := '+';
      Vertical     : Wide_Wide_Character := '|';
      Bottom_Left  : Wide_Wide_Character := '+';
      Bottom_Right : Wide_Wide_Character := '+';
   end record;

   type Frame_Chrome is record
      Border       : Border_Glyphs;
      Shadow_X     : Natural := 0;
      Shadow_Y     : Natural := 0;
      Shadow       : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
   end record;

   --  Every tab edge occupies one cell, preserving width and hit geometry.
   type Tab_Chrome is record
      Normal_Left   : Wide_Wide_Character := ' ';
      Normal_Right  : Wide_Wide_Character := ' ';
      Active_Left   : Wide_Wide_Character := '[';
      Active_Right  : Wide_Wide_Character := ']';
      Focused_Left  : Wide_Wide_Character := '>';
      Focused_Right : Wide_Wide_Character := ' ';
   end record;

   type Window_Chrome is record
      Frame    : Frame_Chrome;
      Close    : Wide_Wide_Character := 'x';
      Resize   : Wide_Wide_Character := '+';
   end record;

   type Dock_Chrome is record
      Collapse        : Wide_Wide_Character := '-';
      Expand          : Wide_Wide_Character := '+';
      Float           : Wide_Wide_Character := '^';
      Dock             : Wide_Wide_Character := 'v';
      Drop_Horizontal  : Wide_Wide_Character := '-';
      Drop_Vertical    : Wide_Wide_Character := '|';
   end record;

   type Skin is record
      Palette : Flyology_TUI.Themes.Palette;
      Desktop : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Panel   : Frame_Chrome;
      Window  : Window_Chrome;
      Tabs    : Tab_Chrome;
      Dock    : Dock_Chrome;
   end record;

   Charm_Default_Skin : constant Skin;
   Charm_Dark_Skin    : constant Skin;
   Charm_Light_Skin   : constant Skin;
   Turbo_Vision_Skin  : constant Skin;

   function Resolve (Id : Skin_Id) return Skin;
   function Next (Id : Skin_Id) return Skin_Id;
   function Label (Id : Skin_Id) return Wide_Wide_String;

private
   function Glyph (Value : Natural) return Wide_Wide_Character is
     (Wide_Wide_Character'Val (Value));

   Turbo_Black : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (0, 0, 0);
   Turbo_Blue : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (0, 0, 168);
   Turbo_Cyan : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (0, 168, 168);
   Turbo_Bright_Cyan : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (85, 255, 255);
   Turbo_Gray : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (170, 170, 170);
   Turbo_Green : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (85, 255, 85);
   Turbo_Red : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (168, 0, 0);
   Turbo_Bright_Red : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (255, 85, 85);
   Turbo_White : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (255, 255, 255);
   Turbo_Yellow : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (255, 255, 85);

   Single_Frame : constant Frame_Chrome :=
     (Border =>
        (Top_Left     => Glyph (16#250C#),
         Horizontal   => Glyph (16#2500#),
         Top_Right    => Glyph (16#2510#),
         Vertical     => Glyph (16#2502#),
         Bottom_Left  => Glyph (16#2514#),
         Bottom_Right => Glyph (16#2518#)),
      others => <>);

   Rounded_Frame : constant Frame_Chrome :=
     (Border =>
        (Top_Left     => Glyph (16#256D#),
         Horizontal   => Glyph (16#2500#),
         Top_Right    => Glyph (16#256E#),
         Vertical     => Glyph (16#2502#),
         Bottom_Left  => Glyph (16#2570#),
         Bottom_Right => Glyph (16#256F#)),
      others => <>);

   Double_Frame : constant Frame_Chrome :=
     (Border =>
        (Top_Left     => Glyph (16#2554#),
         Horizontal   => Glyph (16#2550#),
         Top_Right    => Glyph (16#2557#),
         Vertical     => Glyph (16#2551#),
         Bottom_Left  => Glyph (16#255A#),
         Bottom_Right => Glyph (16#255D#)),
      Shadow_X => 1,
      Shadow_Y => 1,
      Shadow =>
        (Foreground => Turbo_Black,
         Background => Turbo_Black,
         others => <>));

   Charm_Tabs : constant Tab_Chrome :=
     (Normal_Left   => ' ', Normal_Right  => ' ',
      Active_Left   => '[', Active_Right  => ']',
      Focused_Left  => '>', Focused_Right => ' ');

   Turbo_Tabs : constant Tab_Chrome :=
     (Normal_Left   => ' ', Normal_Right  => ' ',
      Active_Left   => Glyph (16#00AB#),
      Active_Right  => Glyph (16#00BB#),
      Focused_Left  => Glyph (16#25BA#),
      Focused_Right => Glyph (16#25C4#));

   Charm_Dock : constant Dock_Chrome :=
     (Collapse => '-', Expand => '+', Float => '^', Dock => 'v',
      Drop_Horizontal => ':', Drop_Vertical => ':');

   Turbo_Dock : constant Dock_Chrome :=
     (Collapse => Glyph (16#25AC#), Expand => Glyph (16#25B2#),
      Float => Glyph (16#25A0#), Dock => Glyph (16#25BC#),
      Drop_Horizontal => Glyph (16#2550#),
      Drop_Vertical => Glyph (16#2551#));

   Turbo_Palette : constant Flyology_TUI.Themes.Palette :=
      (Content =>
        (Foreground => Turbo_White,
         Background => Turbo_Blue, others => <>),
      Muted =>
        (Foreground => Turbo_Bright_Cyan,
         Background => Turbo_Blue, others => <>),
      Title =>
        (Foreground => Turbo_Yellow,
         Background => Turbo_Blue, Bold => True, others => <>),
      Focused =>
        (Foreground => Turbo_Black,
         Background => Turbo_Bright_Cyan, Bold => True, others => <>),
      Interaction =>
        (Foreground => Turbo_Yellow,
         Background => Turbo_Blue, Underline => True, others => <>),
      Selected =>
        (Foreground => Turbo_Black,
         Background => Turbo_White, Bold => True, others => <>),
      Border =>
        (Foreground => Turbo_White,
         Background => Turbo_Blue, others => <>),
      Input =>
        (Foreground => Turbo_Black,
         Background => Turbo_White, others => <>),
      Placeholder =>
        (Foreground => Turbo_Gray,
         Background => Turbo_White, Faint => True, others => <>),
      Error =>
        (Foreground => Turbo_Bright_Red,
         Background => Turbo_Blue, Bold => True, others => <>),
      Success =>
        (Foreground => Turbo_Green,
         Background => Turbo_Blue, Bold => True, others => <>),
      Button =>
        (Foreground => Turbo_Black,
         Background => Turbo_Cyan, others => <>),
      Button_Focused =>
        (Foreground => Turbo_White,
         Background => Turbo_Red, Bold => True, others => <>),
      Button_Pressed =>
        (Foreground => Turbo_Yellow,
         Background => Turbo_Black, Bold => True, others => <>),
      Disabled =>
        (Foreground => Turbo_Gray,
         Background => Turbo_Blue, Faint => True, others => <>));

   Charm_Default_Skin : constant Skin :=
     (Palette => Flyology_TUI.Themes.Charm_Palette,
      Desktop => Flyology_TUI.Styles.Default,
      Panel => Rounded_Frame,
      Window => (Frame => Single_Frame, Close => Glyph (16#00D7#),
                 Resize => '+'),
      Tabs => Charm_Tabs,
      Dock => Charm_Dock);

   Charm_Dark_Skin : constant Skin :=
     (Palette => Flyology_TUI.Themes.Charm_Dark_Palette,
      Desktop => Flyology_TUI.Styles.Default,
      Panel => Rounded_Frame,
      Window => (Frame => Single_Frame, Close => Glyph (16#00D7#),
                 Resize => '+'),
      Tabs => Charm_Tabs,
      Dock => Charm_Dock);

   Charm_Light_Skin : constant Skin :=
     (Palette => Flyology_TUI.Themes.Charm_Light_Palette,
      Desktop => Flyology_TUI.Styles.Default,
      Panel => Rounded_Frame,
      Window => (Frame => Single_Frame, Close => Glyph (16#00D7#),
                 Resize => '+'),
      Tabs => Charm_Tabs,
      Dock => Charm_Dock);

   Turbo_Vision_Skin : constant Skin :=
     (Palette => Turbo_Palette,
      Desktop => Turbo_Palette.Content,
      Panel => Double_Frame,
      Window => (Frame => Double_Frame, Close => Glyph (16#25A0#),
                 Resize => Glyph (16#25C6#)),
      Tabs => Turbo_Tabs,
      Dock => Turbo_Dock);
end Flyology_TUI.Skins;
