with Flyology_TUI.Events;
with Flyology_TUI.Views;

package Flyology_TUI.Backends is
   Backend_Error : exception;

   type Input_Status is (Event_Available, End_Of_Input, Interrupted);

   --  Terminal and test backends implement this interface. The POSIX backend
   --  is the first target; the same boundary is reserved for a future Windows
   --  console backend and optional Flyology-aware wait adapter.
   type Backend is limited interface;

   procedure Open (Item : in out Backend) is abstract;

   --  Close is idempotent and restores every terminal mode changed by Open or
   --  Render. It may be called after partial initialization.
   procedure Close (Item : in out Backend) is abstract;

   --  Wait for one terminal event. Interrupt must make a concurrent call
   --  return promptly with status Interrupted.
   procedure Next_Event
     (Item   : in out Backend;
      Event  : out Flyology_TUI.Events.Terminal_Event;
      Status : out Input_Status) is abstract;

   procedure Render
     (Item : in out Backend;
      View : Flyology_TUI.Views.View) is abstract;

   procedure Interrupt (Item : in out Backend) is abstract;
end Flyology_TUI.Backends;
