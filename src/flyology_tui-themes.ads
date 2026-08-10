with Flyology_TUI.Colors;
with Flyology_TUI.Styles;

package Flyology_TUI.Themes is
   --  Compact semantic presentation roles. Components borrow a Theme only
   --  while rendering; component models never retain it. The record remains
   --  intentionally stable so existing exhaustive aggregates keep compiling.
   type Theme is record
      Primary     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Muted       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selected    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Border      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Input       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Placeholder : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Error       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Success     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   Default : constant Theme := (others => Flyology_TUI.Styles.Default);

   --  A richer render-time vocabulary for controls which distinguish body,
   --  navigation, interaction, selection, and button states. Palette is an
   --  additive boundary: Theme and every explicit Appearance API remain
   --  available, and neither value is retained by component models.
   type Palette is record
      Content     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Muted       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Title       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Interaction : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selected    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Border      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Input       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Placeholder : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Error       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Success     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Button      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Button_Focused :
        Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Button_Pressed :
        Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Disabled : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   Default_Palette : constant Palette :=
     (others => Flyology_TUI.Styles.Default);

   --  Collapse the richer palette into the stable compact theme. Components
   --  that accept Palette can preserve the additional control-state roles.
   function To_Theme (Item : Palette) return Theme is
     (Primary     => Item.Content,
      Muted       => Item.Muted,
      Selected    => Item.Selected,
      Focused     => Item.Focused,
      Border      => Item.Border,
      Input       => Item.Input,
      Placeholder => Item.Placeholder,
      Error       => Item.Error,
      Success     => Item.Success);

   --  Charm keeps content and input at terminal-default colors. Its accent
   --  contrast cannot be inferred from an unknown terminal background;
   --  applications that know the background should choose Charm_Dark or
   --  Charm_Light. All three retain attribute and glyph distinctions after
   --  color-profile downsampling.
   Charm_Palette       : constant Palette;
   Charm_Dark_Palette  : constant Palette;
   Charm_Light_Palette : constant Palette;

   Charm       : constant Theme;
   Charm_Dark  : constant Theme;
   Charm_Light : constant Theme;

private
   Charm_Palette : constant Palette :=
     (Content     => Flyology_TUI.Styles.Default,
      Muted       =>
        (Foreground =>
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Black),
         others => <>),
      Title       =>
        (Foreground => Flyology_TUI.Colors.True_Color (117, 113, 249),
         Bold => True, others => <>),
      Focused     =>
        (Foreground => Flyology_TUI.Colors.True_Color (117, 113, 249),
         Bold => True, Underline => True, others => <>),
      Interaction =>
        (Foreground => Flyology_TUI.Colors.True_Color (247, 128, 226),
         Bold => True, Underline => True, others => <>),
      Selected    =>
        (Foreground => Flyology_TUI.Colors.True_Color (2, 191, 135),
         Bold => True, others => <>),
      Border      =>
        (Foreground =>
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Black),
         others => <>),
      Input       => Flyology_TUI.Styles.Default,
      Placeholder =>
        (Foreground =>
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Black),
         Faint => True, Italic => True, others => <>),
      Error       =>
        (Foreground => Flyology_TUI.Colors.True_Color (237, 86, 122),
         Bold => True, others => <>),
      Success     =>
        (Foreground => Flyology_TUI.Colors.True_Color (2, 191, 135),
         Bold => True, others => <>),
      Button      => Flyology_TUI.Styles.Default,
      Button_Focused =>
        (Foreground => Flyology_TUI.Colors.True_Color (35, 35, 35),
         Background => Flyology_TUI.Colors.True_Color (247, 128, 226),
         Bold => True, others => <>),
      Button_Pressed =>
        (Foreground => Flyology_TUI.Colors.True_Color (255, 253, 245),
         Background => Flyology_TUI.Colors.True_Color (90, 86, 224),
         Bold => True, Underline => True, others => <>),
      Disabled    =>
        (Foreground =>
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Black),
         Faint => True, others => <>));

   Charm_Dark_Palette : constant Palette :=
     (Content     =>
        (Foreground => Flyology_TUI.Colors.True_Color (255, 253, 245),
         others => <>),
      Muted       =>
        (Foreground => Flyology_TUI.Colors.True_Color (155, 155, 155),
         others => <>),
      Title       =>
        (Foreground => Flyology_TUI.Colors.True_Color (117, 113, 249),
         Bold => True, others => <>),
      Focused     =>
        (Foreground => Flyology_TUI.Colors.True_Color (117, 113, 249),
         Bold => True, Underline => True, others => <>),
      Interaction =>
        (Foreground => Flyology_TUI.Colors.True_Color (247, 128, 226),
         Bold => True, Underline => True, others => <>),
      Selected    =>
        (Foreground => Flyology_TUI.Colors.True_Color (2, 191, 135),
         Bold => True, others => <>),
      Border      =>
        (Foreground => Flyology_TUI.Colors.True_Color (98, 98, 98),
         others => <>),
      Input       =>
        (Foreground => Flyology_TUI.Colors.True_Color (255, 253, 245),
         others => <>),
      Placeholder =>
        (Foreground => Flyology_TUI.Colors.True_Color (118, 118, 118),
         Faint => True, Italic => True, others => <>),
      Error       =>
        (Foreground => Flyology_TUI.Colors.True_Color (237, 86, 122),
         Bold => True, others => <>),
      Success     =>
        (Foreground => Flyology_TUI.Colors.True_Color (2, 191, 135),
         Bold => True, others => <>),
      Button      =>
        (Foreground => Flyology_TUI.Colors.True_Color (255, 253, 245),
         Background => Flyology_TUI.Colors.True_Color (53, 53, 53),
         others => <>),
      Button_Focused =>
        (Foreground => Flyology_TUI.Colors.True_Color (35, 35, 35),
         Background => Flyology_TUI.Colors.True_Color (247, 128, 226),
         Bold => True, others => <>),
      Button_Pressed =>
        (Foreground => Flyology_TUI.Colors.True_Color (255, 253, 245),
         Background => Flyology_TUI.Colors.True_Color (90, 86, 224),
         Bold => True, Underline => True, others => <>),
      Disabled    =>
        (Foreground => Flyology_TUI.Colors.True_Color (118, 118, 118),
         Faint => True, others => <>));

   Charm_Light_Palette : constant Palette :=
     (Content     =>
        (Foreground => Flyology_TUI.Colors.True_Color (35, 35, 35),
         others => <>),
      Muted       =>
        (Foreground => Flyology_TUI.Colors.True_Color (98, 98, 98),
         others => <>),
      Title       =>
        (Foreground => Flyology_TUI.Colors.True_Color (90, 86, 224),
         Bold => True, others => <>),
      Focused     =>
        (Foreground => Flyology_TUI.Colors.True_Color (90, 86, 224),
         Bold => True, Underline => True, others => <>),
      Interaction =>
        (Foreground => Flyology_TUI.Colors.True_Color (184, 50, 169),
         Bold => True, Underline => True, others => <>),
      Selected    =>
        (Foreground => Flyology_TUI.Colors.True_Color (0, 122, 85),
         Bold => True, others => <>),
      Border      =>
        (Foreground => Flyology_TUI.Colors.True_Color (118, 118, 118),
         others => <>),
      Input       =>
        (Foreground => Flyology_TUI.Colors.True_Color (35, 35, 35),
         others => <>),
      Placeholder =>
        (Foreground => Flyology_TUI.Colors.True_Color (118, 118, 118),
         Faint => True, Italic => True, others => <>),
      Error       =>
        (Foreground => Flyology_TUI.Colors.True_Color (198, 40, 80),
         Bold => True, others => <>),
      Success     =>
        (Foreground => Flyology_TUI.Colors.True_Color (0, 122, 85),
         Bold => True, others => <>),
      Button      =>
        (Foreground => Flyology_TUI.Colors.True_Color (35, 35, 35),
         Background => Flyology_TUI.Colors.True_Color (232, 232, 232),
         others => <>),
      Button_Focused =>
        (Foreground => Flyology_TUI.Colors.True_Color (255, 253, 245),
         Background => Flyology_TUI.Colors.True_Color (184, 50, 169),
         Bold => True, others => <>),
      Button_Pressed =>
        (Foreground => Flyology_TUI.Colors.True_Color (255, 253, 245),
         Background => Flyology_TUI.Colors.True_Color (90, 86, 224),
         Bold => True, Underline => True, others => <>),
      Disabled    =>
        (Foreground => Flyology_TUI.Colors.True_Color (118, 118, 118),
         Faint => True, others => <>));

   Charm       : constant Theme := To_Theme (Charm_Palette);
   Charm_Dark  : constant Theme := To_Theme (Charm_Dark_Palette);
   Charm_Light : constant Theme := To_Theme (Charm_Light_Palette);
end Flyology_TUI.Themes;
