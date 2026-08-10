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

   type Title_Placement is (Leading_Title, Centered_Title);
   type Control_Placement is (Leading_Control, Trailing_Control);

   type Panel_Chrome is record
      Frame : Frame_Chrome;
      Title : Title_Placement := Leading_Title;
   end record;

   --  Every tab edge occupies one cell, preserving width and hit geometry.
   type Tab_Chrome is record
      Normal_Left   : Wide_Wide_Character := ' ';
      Normal_Right  : Wide_Wide_Character := ' ';
      Active_Left   : Wide_Wide_Character := '[';
      Active_Right  : Wide_Wide_Character := ']';
      Focused_Left  : Wide_Wide_Character := '>';
      Focused_Right : Wide_Wide_Character := ' ';
      Mnemonic_First : Boolean := False;
   end record;

   type Window_Chrome is record
      Frame          : Frame_Chrome;
      Focused_Frame  : Frame_Chrome;
      Title          : Title_Placement := Leading_Title;
      Close_Position : Control_Placement := Trailing_Control;
      Close_Left     : Wide_Wide_Character := ' ';
      Close           : Wide_Wide_Character := 'x';
      Close_Right    : Wide_Wide_Character := ' ';
      Resize          : Wide_Wide_Character := '+';
      Active_Controls_Only : Boolean := False;
   end record;

   --  Button bodies retain their four-cell horizontal affordance. A shadow
   --  may extend the rendered surface without becoming part of the hit area.
   type Button_Chrome is record
      Left_Outer  : Wide_Wide_Character := '[';
      Left_Inner  : Wide_Wide_Character := ' ';
      Right_Inner : Wide_Wide_Character := ' ';
      Right_Outer : Wide_Wide_Character := ']';
      Shadow_X    : Natural := 0;
      Shadow_Y    : Natural := 0;
      Shadow      : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Depress     : Boolean := False;
   end record;

   type Choice_Chrome is record
      Check_On    : Wide_Wide_Character := 'x';
      Check_Mixed : Wide_Wide_Character := '-';
      Radio_On    : Wide_Wide_Character := 'o';
   end record;

   type Scrollbar_Chrome is record
      Left_Arrow  : Wide_Wide_Character :=
        Wide_Wide_Character'Val (16#25C0#);
      Right_Arrow : Wide_Wide_Character :=
        Wide_Wide_Character'Val (16#25B6#);
      Up_Arrow    : Wide_Wide_Character :=
        Wide_Wide_Character'Val (16#25B2#);
      Down_Arrow  : Wide_Wide_Character :=
        Wide_Wide_Character'Val (16#25BC#);
      Track       : Wide_Wide_Character :=
        Wide_Wide_Character'Val (16#2591#);
      Thumb       : Wide_Wide_Character :=
        Wide_Wide_Character'Val (16#2588#);
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
      Palette          : Flyology_TUI.Themes.Palette;
      Desktop          : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Menu_Bar         : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Status_Line      : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Dialog           : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Control          : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Control_Focused  : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Control_Selected : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Panel            : Panel_Chrome;
      Window           : Window_Chrome;
      Button           : Button_Chrome;
      Choice           : Choice_Chrome;
      Scrollbar        : Scrollbar_Chrome;
      Tabs             : Tab_Chrome;
      Dock             : Dock_Chrome;
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
   Turbo_Desktop : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (0, 168, 168);
   Turbo_Dialog : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (168, 168, 168);
   Turbo_Dark_Gray : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (84, 84, 84);
   Turbo_Bright_Cyan : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (85, 255, 255);
   Turbo_Green : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (0, 168, 0);
   Turbo_Red : constant Flyology_TUI.Colors.Color :=
     Flyology_TUI.Colors.True_Color (168, 0, 0);
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
      Focused_Left  => '>', Focused_Right => ' ',
      Mnemonic_First => False);

   Turbo_Tabs : constant Tab_Chrome :=
     (Normal_Left   => ' ', Normal_Right  => ' ',
      Active_Left   => ' ', Active_Right  => ' ',
      Focused_Left  => ' ', Focused_Right => ' ',
      Mnemonic_First => True);

   Charm_Button : constant Button_Chrome := (others => <>);

   Turbo_Button : constant Button_Chrome :=
     (Left_Outer => ' ', Left_Inner => ' ',
      Right_Inner => ' ', Right_Outer => ' ',
      Shadow_X => 1, Shadow_Y => 1,
      Shadow =>
        (Foreground => Turbo_Black, Background => Turbo_Black,
         others => <>),
      Depress => True);

   Charm_Choice : constant Choice_Chrome := (others => <>);

   Turbo_Choice : constant Choice_Chrome :=
     (Check_On => 'X', Check_Mixed => '-',
      Radio_On => Glyph (16#2022#));

   Charm_Scrollbar : constant Scrollbar_Chrome := (others => <>);

   Turbo_Scrollbar : constant Scrollbar_Chrome :=
     (Left_Arrow => Glyph (16#25C4#), Right_Arrow => Glyph (16#25BA#),
      Up_Arrow => Glyph (16#25B2#), Down_Arrow => Glyph (16#25BC#),
      Track => Glyph (16#2592#), Thumb => Glyph (16#2588#));

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
        (Foreground => Turbo_Blue,
         Background => Turbo_Dialog, others => <>),
      Title =>
        (Foreground => Turbo_Blue,
         Background => Turbo_Dialog, Bold => True, others => <>),
      Focused =>
        (Foreground => Turbo_White,
         Background => Turbo_Blue, Bold => True, Underline => True,
         Reverse_Video => True, others => <>),
      Interaction =>
        (Foreground => Turbo_Red,
         Background => Turbo_Dialog, Bold => True, Underline => True,
         others => <>),
      Selected =>
        (Foreground => Turbo_Desktop,
         Background => Turbo_Black, Bold => True, Reverse_Video => True,
         others => <>),
      Border =>
        (Foreground => Turbo_White,
         Background => Turbo_Blue, others => <>),
      Input =>
        (Foreground => Turbo_White,
         Background => Turbo_Blue, others => <>),
      Placeholder =>
        (Foreground => Turbo_Bright_Cyan,
         Background => Turbo_Blue, Faint => True, others => <>),
      Error =>
        (Foreground => Turbo_Red,
         Background => Turbo_Dialog, Bold => True, others => <>),
      Success =>
        (Foreground => Turbo_Green,
         Background => Turbo_Dialog, Bold => True, others => <>),
      Button =>
        (Foreground => Turbo_Black,
         Background => Turbo_Green, Bold => True, others => <>),
      Button_Focused =>
        (Foreground => Turbo_White,
         Background => Turbo_Blue, Bold => True, Underline => True,
         Reverse_Video => True, others => <>),
      Button_Pressed =>
        (Foreground => Turbo_Yellow,
         Background => Turbo_Blue, Bold => True, others => <>),
      Disabled =>
        (Foreground => Turbo_Dark_Gray,
         Background => Turbo_Dialog, Faint => True, others => <>));

   Charm_Default_Skin : constant Skin :=
     (Palette => Flyology_TUI.Themes.Charm_Palette,
      Desktop => Flyology_TUI.Styles.Default,
      Menu_Bar => Flyology_TUI.Styles.Default,
      Status_Line => Flyology_TUI.Styles.Default,
      Dialog => Flyology_TUI.Themes.Charm_Palette.Content,
      Control => Flyology_TUI.Themes.Charm_Palette.Content,
      Control_Focused => Flyology_TUI.Themes.Charm_Palette.Interaction,
      Control_Selected => Flyology_TUI.Themes.Charm_Palette.Selected,
      Panel => (Frame => Rounded_Frame, Title => Leading_Title),
      Window =>
        (Frame => Single_Frame, Focused_Frame => Single_Frame,
         Close => Glyph (16#00D7#), Resize => '+', others => <>),
      Button => Charm_Button,
      Choice => Charm_Choice,
      Scrollbar => Charm_Scrollbar,
      Tabs => Charm_Tabs,
      Dock => Charm_Dock);

   Charm_Dark_Skin : constant Skin :=
      (Palette => Flyology_TUI.Themes.Charm_Dark_Palette,
      Desktop => Flyology_TUI.Styles.Default,
      Menu_Bar => Flyology_TUI.Styles.Default,
      Status_Line => Flyology_TUI.Styles.Default,
      Dialog => Flyology_TUI.Themes.Charm_Dark_Palette.Content,
      Control => Flyology_TUI.Themes.Charm_Dark_Palette.Content,
      Control_Focused => Flyology_TUI.Themes.Charm_Dark_Palette.Interaction,
      Control_Selected => Flyology_TUI.Themes.Charm_Dark_Palette.Selected,
      Panel => (Frame => Rounded_Frame, Title => Leading_Title),
      Window =>
        (Frame => Single_Frame, Focused_Frame => Single_Frame,
         Close => Glyph (16#00D7#), Resize => '+', others => <>),
      Button => Charm_Button,
      Choice => Charm_Choice,
      Scrollbar => Charm_Scrollbar,
      Tabs => Charm_Tabs,
      Dock => Charm_Dock);

   Charm_Light_Skin : constant Skin :=
      (Palette => Flyology_TUI.Themes.Charm_Light_Palette,
      Desktop => Flyology_TUI.Styles.Default,
      Menu_Bar => Flyology_TUI.Styles.Default,
      Status_Line => Flyology_TUI.Styles.Default,
      Dialog => Flyology_TUI.Themes.Charm_Light_Palette.Content,
      Control => Flyology_TUI.Themes.Charm_Light_Palette.Content,
      Control_Focused => Flyology_TUI.Themes.Charm_Light_Palette.Interaction,
      Control_Selected => Flyology_TUI.Themes.Charm_Light_Palette.Selected,
      Panel => (Frame => Rounded_Frame, Title => Leading_Title),
      Window =>
        (Frame => Single_Frame, Focused_Frame => Single_Frame,
         Close => Glyph (16#00D7#), Resize => '+', others => <>),
      Button => Charm_Button,
      Choice => Charm_Choice,
      Scrollbar => Charm_Scrollbar,
      Tabs => Charm_Tabs,
      Dock => Charm_Dock);

   Turbo_Vision_Skin : constant Skin :=
      (Palette => Turbo_Palette,
      Desktop =>
        (Foreground => Turbo_White, Background => Turbo_Blue,
         others => <>),
      Menu_Bar =>
        (Foreground => Turbo_Black, Background => Turbo_Dialog,
         others => <>),
      Status_Line =>
        (Foreground => Turbo_Black, Background => Turbo_Dialog,
         others => <>),
      Dialog =>
        (Foreground => Turbo_Black, Background => Turbo_Dialog,
         others => <>),
      Control =>
        (Foreground => Turbo_Black, Background => Turbo_Desktop,
         others => <>),
      Control_Focused =>
        (Foreground => Turbo_White, Background => Turbo_Blue,
         Bold => True, Underline => True, Reverse_Video => True,
         others => <>),
      Control_Selected =>
        (Foreground => Turbo_Green, Background => Turbo_Black,
         Bold => True, Reverse_Video => True, others => <>),
      Panel => (Frame => Double_Frame, Title => Centered_Title),
      Window =>
        (Frame => Single_Frame, Focused_Frame => Double_Frame,
         Title => Centered_Title, Close_Position => Leading_Control,
         Close_Left => '[', Close => Glyph (16#25A0#),
         Close_Right => ']', Resize => Glyph (16#25C6#),
         Active_Controls_Only => True),
      Button => Turbo_Button,
      Choice => Turbo_Choice,
      Scrollbar => Turbo_Scrollbar,
      Tabs => Turbo_Tabs,
      Dock => Turbo_Dock);
end Flyology_TUI.Skins;
