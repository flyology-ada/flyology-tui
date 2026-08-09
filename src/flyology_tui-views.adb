package body Flyology_TUI.Views is

   function Plain (Content : Wide_Wide_String) return View is
     (Frame  => Flyology_TUI.Surfaces.From_Text (Content),
      others  => <>);

   function Styled
     (Content    : Wide_Wide_String;
      Appearance : Flyology_TUI.Styles.Style) return View
   is (Frame  => Flyology_TUI.Surfaces.From_Text (Content, Appearance),
       others => <>);

   function From_Surface (Frame : Flyology_TUI.Surfaces.Surface) return View is
     (Frame => Frame, others => <>);

end Flyology_TUI.Views;
