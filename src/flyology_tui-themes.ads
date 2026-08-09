with Flyology_TUI.Colors;
with Flyology_TUI.Styles;

package Flyology_TUI.Themes is
   --  Semantic presentation roles. Components borrow a Theme only while
   --  rendering; component models never retain it.
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

   --  A restrained dark-terminal preset derived from the visual vocabulary
   --  used by Charm's terminal libraries. Copy the value and replace any role
   --  to customize it for an application.
   Charm : constant Theme :=
     (Primary =>
        Flyology_TUI.Styles.Emphasized
          (Flyology_TUI.Styles.With_Foreground
             (Flyology_TUI.Styles.Default,
              Flyology_TUI.Colors.True_Color (214, 159, 255))),
      Muted =>
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Black)),
      Selected =>
        Flyology_TUI.Styles.With_Background
          (Flyology_TUI.Styles.Emphasized
             (Flyology_TUI.Styles.With_Foreground
                (Flyology_TUI.Styles.Default,
                 Flyology_TUI.Colors.True_Color (214, 159, 255))),
           Flyology_TUI.Colors.Palette (236)),
      Focused =>
        Flyology_TUI.Styles.Emphasized
          (Flyology_TUI.Styles.With_Foreground
             (Flyology_TUI.Styles.Default,
              Flyology_TUI.Colors.True_Color (214, 159, 255))),
      Border =>
        Flyology_TUI.Styles.Emphasized
          (Flyology_TUI.Styles.With_Foreground
             (Flyology_TUI.Styles.Default,
              Flyology_TUI.Colors.True_Color (214, 159, 255))),
      Input =>
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.True_Color (110, 231, 255)),
      Placeholder =>
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Black)),
      Error =>
        Flyology_TUI.Styles.Emphasized
          (Flyology_TUI.Styles.With_Foreground
             (Flyology_TUI.Styles.Default,
              Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Red))),
      Success =>
        Flyology_TUI.Styles.Emphasized
          (Flyology_TUI.Styles.With_Foreground
             (Flyology_TUI.Styles.Default,
              Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Green))));
end Flyology_TUI.Themes;
