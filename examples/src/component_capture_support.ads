with Flyology_TUI.Skins;
with Flyology_TUI.Surfaces;

package Component_Capture_Support is
   procedure Write_SVG
     (Frame : Flyology_TUI.Surfaces.Surface;
      Skin  : Flyology_TUI.Skins.Skin_Id;
      Title : Wide_Wide_String;
      Path  : String);
end Component_Capture_Support;
