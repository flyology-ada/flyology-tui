with Ada.Finalization;
with Interfaces.C;
with System;
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
   end record;

   overriding procedure Finalize (Item : in out POSIX_Backend);
end Flyology_TUI.Backends.POSIX;
