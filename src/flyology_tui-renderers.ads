with Ada.Strings.Unbounded;
with Flyology_TUI.Color_Profiles;
with Flyology_TUI.Views;

package Flyology_TUI.Renderers is
   package Bytes renames Ada.Strings.Unbounded;

   type Renderer is tagged private;

   --  Select the color encoding used by subsequent frames. Changing the
   --  profile after rendering forces one complete frame repaint.
   procedure Set_Color_Profile
     (Item    : in out Renderer;
      Profile : Flyology_TUI.Color_Profiles.Profile);

   function Color_Profile
     (Item : Renderer) return Flyology_TUI.Color_Profiles.Profile;

   --  Render returns terminal bytes containing declarative mode changes and
   --  only those cells that differ from the previous frame.
   procedure Render
     (Item    : in out Renderer;
      Desired : Flyology_TUI.Views.View;
      Output  : out Bytes.Unbounded_String);

   --  Restore all modes which may have been enabled by Render. Reset is safe
   --  before the first Render and may be called more than once.
   procedure Reset
     (Item   : in out Renderer;
      Output : out Bytes.Unbounded_String);

private
   type Renderer is tagged record
      Initialized      : Boolean := False;
      Configured_Color : Flyology_TUI.Color_Profiles.Profile :=
        Flyology_TUI.Color_Profiles.Truecolor;
      Rendered_Color   : Flyology_TUI.Color_Profiles.Profile :=
        Flyology_TUI.Color_Profiles.Truecolor;
      Previous         : Flyology_TUI.Views.View;
   end record;
end Flyology_TUI.Renderers;
