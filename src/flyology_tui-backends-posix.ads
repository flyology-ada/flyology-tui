with Ada.Finalization;
with Interfaces.C;
with System;
with Flyology_TUI.Color_Profiles;
with Flyology_TUI.Input;
with Flyology_TUI.Renderers;

package Flyology_TUI.Backends.POSIX is
   use type Interfaces.C.int;
   type POSIX_Backend is
     new Ada.Finalization.Limited_Controlled and Backend with private;

   overriding procedure Open (Item : in out POSIX_Backend);
   overriding procedure Current_Size
     (Item      : POSIX_Backend;
      Width     : in out Natural;
      Height    : in out Natural;
      Available : in out Boolean);
   overriding procedure Close (Item : in out POSIX_Backend);
   overriding procedure Next_Event
     (Item   : in out POSIX_Backend;
      Event  : out Flyology_TUI.Events.Terminal_Event;
      Status : out Input_Status);
   overriding procedure Render
     (Item : in out POSIX_Backend;
      View : Flyology_TUI.Views.View);
   overriding procedure Interrupt (Item : in out POSIX_Backend);

   --  Override environment-based color detection for the next Open. Changing
   --  this policy while the backend is open raises Backend_Error.
   procedure Set_Color_Policy
     (Item   : in out POSIX_Backend;
      Policy : Flyology_TUI.Color_Profiles.Policy);

   function Color_Policy
     (Item : POSIX_Backend) return Flyology_TUI.Color_Profiles.Policy;

   --  Return the profile resolved by Open. Calling this while closed raises
   --  Backend_Error.
   function Color_Profile
     (Item : POSIX_Backend) return Flyology_TUI.Color_Profiles.Profile;

private
   type POSIX_Backend is
     new Ada.Finalization.Limited_Controlled and Backend with record
      Is_Open       : Boolean := False;
      Raw_State     : System.Address := System.Null_Address;
      Wake_Read     : aliased Interfaces.C.int := -1;
      Wake_Write    : aliased Interfaces.C.int := -1;
      Last_Width    : Natural := 0;
      Last_Height   : Natural := 0;
      Size_Available : Boolean := False;
      Input_Parser  : Flyology_TUI.Input.Parser;
      Frame_Renderer : Flyology_TUI.Renderers.Renderer;
      Requested_Color : Flyology_TUI.Color_Profiles.Policy :=
        Flyology_TUI.Color_Profiles.Automatic;
      Effective_Color : Flyology_TUI.Color_Profiles.Profile :=
        Flyology_TUI.Color_Profiles.Truecolor;
   end record;

   overriding procedure Finalize (Item : in out POSIX_Backend);
end Flyology_TUI.Backends.POSIX;
