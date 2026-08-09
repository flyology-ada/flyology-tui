with Ada.Finalization;

package Flyology_TUI.Backends.Headless is
   type Headless_Backend (Event_Capacity : Positive := 256) is
     new Ada.Finalization.Limited_Controlled and Backend with private;

   overriding procedure Open (Item : in out Headless_Backend);
   overriding procedure Current_Size
     (Item      : Headless_Backend;
      Width     : in out Natural;
      Height    : in out Natural;
      Available : in out Boolean);
   overriding procedure Close (Item : in out Headless_Backend);
   overriding procedure Next_Event
     (Item   : in out Headless_Backend;
      Event  : out Flyology_TUI.Events.Terminal_Event;
      Status : out Input_Status);
   overriding procedure Render
     (Item : in out Headless_Backend;
      View : Flyology_TUI.Views.View);
   overriding procedure Interrupt (Item : in out Headless_Backend);

   procedure Queue_Event
     (Item  : in out Headless_Backend;
      Event : Flyology_TUI.Events.Terminal_Event);
   procedure Finish_Input (Item : in out Headless_Backend);
   --  Configure the size reported after the next Open without consuming an
   --  input event. Configuration while open raises Backend_Error.
   procedure Set_Initial_Size
     (Item : in out Headless_Backend; Width, Height : Natural);

   function Render_Count (Item : Headless_Backend) return Natural;
   function Last_View (Item : Headless_Backend) return Flyology_TUI.Views.View;
   function Is_Open (Item : Headless_Backend) return Boolean;

private
   type Event_Array is
     array (Positive range <>) of Flyology_TUI.Events.Terminal_Event;

   protected type Event_Buffer (Capacity : Positive) is
      procedure Put (Event : Flyology_TUI.Events.Terminal_Event);
      entry Get
        (Event  : out Flyology_TUI.Events.Terminal_Event;
         Status : out Input_Status);
      procedure Finish;
      procedure Wake;
   private
      Values      : Event_Array (1 .. Capacity);
      Head        : Positive := 1;
      Tail        : Positive := 1;
      Count       : Natural := 0;
      Is_Finished : Boolean := False;
      Is_Woken    : Boolean := False;
   end Event_Buffer;

   type Headless_Backend (Event_Capacity : Positive := 256) is
     new Ada.Finalization.Limited_Controlled and Backend with record
      Events      : Event_Buffer (Event_Capacity);
      Opened      : Boolean := False;
      Width       : Natural := 0;
      Height      : Natural := 0;
      Size_Set    : Boolean := False;
      Frames      : Natural := 0;
      Current     : Flyology_TUI.Views.View;
   end record;

   overriding procedure Finalize (Item : in out Headless_Backend);
end Flyology_TUI.Backends.Headless;
