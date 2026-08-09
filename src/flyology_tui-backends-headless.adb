package body Flyology_TUI.Backends.Headless is

   protected body Event_Buffer is
      procedure Put (Event : Flyology_TUI.Events.Terminal_Event) is
      begin
         if Is_Finished then
            raise Backend_Error with "headless input is finished";
         elsif Count = Capacity then
            raise Backend_Error with "headless input capacity exceeded";
         end if;
         Values (Tail) := Event;
         Tail := (if Tail = Capacity then 1 else Tail + 1);
         Count := Count + 1;
      end Put;

      entry Get
        (Event  : out Flyology_TUI.Events.Terminal_Event;
         Status : out Input_Status)
        when Count > 0 or else Is_Finished or else Is_Woken
      is
      begin
         if Is_Woken then
            Is_Woken := False;
            Event := (Kind => Flyology_TUI.Events.Interrupt);
            Status := Interrupted;
         elsif Count > 0 then
            Event := Values (Head);
            Head := (if Head = Capacity then 1 else Head + 1);
            Count := Count - 1;
            Status := Event_Available;
         else
            Event := (Kind => Flyology_TUI.Events.Interrupt);
            Status := End_Of_Input;
         end if;
      end Get;

      procedure Finish is
      begin
         Is_Finished := True;
      end Finish;

      procedure Wake is
      begin
         Is_Woken := True;
      end Wake;
   end Event_Buffer;

   overriding procedure Open (Item : in out Headless_Backend) is
   begin
      Item.Opened := True;
   end Open;

   overriding procedure Current_Size
     (Item      : Headless_Backend;
      Width     : in out Natural;
      Height    : in out Natural;
      Available : in out Boolean) is
   begin
      Width := Item.Width;
      Height := Item.Height;
      Available := Item.Opened and then Item.Size_Set;
   end Current_Size;

   overriding procedure Close (Item : in out Headless_Backend) is
   begin
      Item.Opened := False;
      Item.Events.Wake;
   end Close;

   overriding procedure Next_Event
     (Item   : in out Headless_Backend;
      Event  : out Flyology_TUI.Events.Terminal_Event;
      Status : out Input_Status) is
   begin
      if not Item.Opened then
         raise Backend_Error with "headless backend is not open";
      end if;
      Item.Events.Get (Event, Status);
   end Next_Event;

   overriding procedure Render
     (Item : in out Headless_Backend;
      View : Flyology_TUI.Views.View) is
   begin
      if not Item.Opened then
         raise Backend_Error with "headless backend is not open";
      end if;
      Item.Current := View;
      Item.Frames := Item.Frames + 1;
   end Render;

   overriding procedure Interrupt (Item : in out Headless_Backend) is
   begin
      Item.Events.Wake;
   end Interrupt;

   procedure Queue_Event
     (Item  : in out Headless_Backend;
      Event : Flyology_TUI.Events.Terminal_Event) is
   begin
      Item.Events.Put (Event);
   end Queue_Event;

   procedure Finish_Input (Item : in out Headless_Backend) is
   begin
      Item.Events.Finish;
   end Finish_Input;

   procedure Set_Initial_Size
     (Item : in out Headless_Backend; Width, Height : Natural) is
   begin
      if Item.Opened then
         raise Backend_Error with
           "headless opening size cannot be changed while open";
      end if;
      Item.Width := Width;
      Item.Height := Height;
      Item.Size_Set := True;
   end Set_Initial_Size;

   function Render_Count (Item : Headless_Backend) return Natural is
     (Item.Frames);

   function Last_View (Item : Headless_Backend)
      return Flyology_TUI.Views.View
   is
     (Item.Current);

   function Is_Open (Item : Headless_Backend) return Boolean is
     (Item.Opened);

   overriding procedure Finalize (Item : in out Headless_Backend) is
   begin
      Close (Item);
   end Finalize;

end Flyology_TUI.Backends.Headless;
