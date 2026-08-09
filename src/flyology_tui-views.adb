package body Flyology_TUI.Views is

   function Plain (Content : Wide_Wide_String) return View is
     (Content => Text.To_Unbounded_Wide_Wide_String (Content),
      others  => <>);

end Flyology_TUI.Views;
