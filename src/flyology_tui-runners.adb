with Flyology_TUI.Events;
with Flyology_TUI.Programs;

package body Flyology_TUI.Runners is
   use type Flyology_TUI.Backends.Input_Status;

   package Program is new Flyology_TUI.Programs
     (Events      => Events,
      Transitions => Transitions,
      Model_Type  => Model_Type,
      Initialize  => Initialize,
      Update      => Update,
      Present     => Present);

   type Event_Array is array (Positive range <>) of Events.Event;
   type Command_Array is array (Positive range <>) of Transitions.Command;

   protected type Event_Queue is
      entry Put (Item : Events.Event; Accepted : out Boolean);
      entry Get (Item : out Events.Event; Available : out Boolean);
      procedure Close;
   private
      Values : Event_Array (1 .. Event_Capacity);
      Head   : Positive := 1;
      Tail   : Positive := 1;
      Count  : Natural := 0;
      Closed : Boolean := False;
   end Event_Queue;

   protected body Event_Queue is
      entry Put (Item : Events.Event; Accepted : out Boolean)
        when Count < Event_Capacity or else Closed
      is
      begin
         Accepted := not Closed;
         if Accepted then
            Values (Tail) := Item;
            Tail := (if Tail = Event_Capacity then 1 else Tail + 1);
            Count := Count + 1;
         end if;
      end Put;

      entry Get (Item : out Events.Event; Available : out Boolean)
        when Count > 0 or else Closed
      is
      begin
         Available := Count > 0;
         if Available then
            Item := Values (Head);
            Head := (if Head = Event_Capacity then 1 else Head + 1);
            Count := Count - 1;
         end if;
      end Get;

      procedure Close is
      begin
         Closed := True;
      end Close;
   end Event_Queue;

   protected type Command_Queue is
      entry Put (Item : Transitions.Command; Accepted : out Boolean);
      entry Get (Item : out Transitions.Command; Available : out Boolean);
      procedure Close;
   private
      Values : Command_Array (1 .. Command_Capacity);
      Head   : Positive := 1;
      Tail   : Positive := 1;
      Count  : Natural := 0;
      Closed : Boolean := False;
   end Command_Queue;

   protected body Command_Queue is
      entry Put (Item : Transitions.Command; Accepted : out Boolean)
        when Count < Command_Capacity or else Closed
      is
      begin
         Accepted := not Closed;
         if Accepted then
            Values (Tail) := Item;
            Tail := (if Tail = Command_Capacity then 1 else Tail + 1);
            Count := Count + 1;
         end if;
      end Put;

      entry Get (Item : out Transitions.Command; Available : out Boolean)
        when Count > 0 or else Closed
      is
      begin
         Available := Count > 0;
         if Available then
            Item := Values (Head);
            Head := (if Head = Command_Capacity then 1 else Head + 1);
            Count := Count - 1;
         end if;
      end Get;

      procedure Close is
      begin
         Closed := True;
      end Close;
   end Command_Queue;

   protected type Failure_State is
      procedure Set;
      function Failed return Boolean;
   private
      Is_Failed : Boolean := False;
   end Failure_State;

   protected body Failure_State is
      procedure Set is
      begin
         Is_Failed := True;
      end Set;

      function Failed return Boolean is (Is_Failed);
   end Failure_State;

   procedure Run
     (Model   : in out Model_Type;
      Backend : in out Flyology_TUI.Backends.Backend'Class)
   is
      Inbox   : Event_Queue;
      Commands : Command_Queue;
      Failure : Failure_State;
      Next    : Transitions.Transition;
      Opened  : Boolean := False;
      Initial_Width, Initial_Height : Natural := 0;
      Initial_Size_Available : Boolean := False;
      Initial_Command_Pending : Boolean := False;
      Initial_Quit_Pending : Boolean := False;
      Initial_Command : Transitions.Command;

      procedure Queue_Command is
         Accepted : Boolean;
      begin
         if Transitions.Has_Command (Next) then
            Commands.Put
              (Transitions.Pending_Command (Next), Accepted);
         end if;
      end Queue_Command;

      procedure Stop_Workers is
      begin
         Commands.Close;
         Inbox.Close;
         if Opened then
            begin
               Flyology_TUI.Backends.Interrupt (Backend);
            exception
               when others => null;
            end;
         end if;
      end Stop_Workers;
   begin
      begin
         Flyology_TUI.Backends.Open (Backend);
      exception
         when others =>
            begin
               Flyology_TUI.Backends.Close (Backend);
            exception
               when others => null;
            end;
            raise;
      end;
      Opened := True;
      begin
         Flyology_TUI.Backends.Current_Size
           (Backend,
            Initial_Width,
            Initial_Height,
            Initial_Size_Available);
         Program.Start (Model, Next);
         if Initial_Size_Available then
            Initial_Quit_Pending := Transitions.Should_Quit (Next);
            if Transitions.Has_Command (Next) then
               Initial_Command := Transitions.Pending_Command (Next);
               Initial_Command_Pending := True;
            end if;
            Program.Dispatch
              (Model,
               Events.From_Terminal
                 (Flyology_TUI.Events.Resized
                    (Initial_Width, Initial_Height)),
               Next);
            if Initial_Quit_Pending then
               Transitions.Quit (Next);
            end if;
         end if;
         Flyology_TUI.Backends.Render
           (Backend, Program.Current_View (Model));

         declare
            task Input_Worker;
            task Command_Worker;

            task body Input_Worker is
               Terminal : Flyology_TUI.Events.Terminal_Event;
               Status : Flyology_TUI.Backends.Input_Status;
               Accepted : Boolean;
            begin
               loop
                  Flyology_TUI.Backends.Next_Event
                    (Backend, Terminal, Status);
                  exit when Status = Flyology_TUI.Backends.Interrupted;
                  Inbox.Put (Events.From_Terminal (Terminal), Accepted);
                  exit when not Accepted
                    or else Status = Flyology_TUI.Backends.End_Of_Input;
               end loop;
               Inbox.Close;
            exception
               when others =>
                  Failure.Set;
                  Inbox.Close;
            end Input_Worker;

            task body Command_Worker is
               Command : Transitions.Command;
               Available, Produced, Accepted : Boolean;
               Message : Events.Message;
            begin
               loop
                  Commands.Get (Command, Available);
                  exit when not Available;
                  Execute (Command, Message, Produced);
                  if Produced then
                     Inbox.Put (Events.From_Message (Message), Accepted);
                     exit when not Accepted;
                  end if;
               end loop;
            exception
               when others =>
                  Failure.Set;
                  Inbox.Close;
            end Command_Worker;

            Event : Events.Event;
            Available : Boolean;
         begin
            --  The workers are active before either preserved transition is
            --  enqueued, so capacity-one command queues cannot deadlock when
            --  Initialize and the synthetic Resize both request effects.
            if Initial_Command_Pending then
               declare
                  Accepted : Boolean;
               begin
                  Commands.Put (Initial_Command, Accepted);
               end;
            end if;
            Queue_Command;
            loop
               exit when Transitions.Should_Quit (Next);
               Inbox.Get (Event, Available);
               exit when not Available;
               Program.Dispatch (Model, Event, Next);
               Flyology_TUI.Backends.Render
                 (Backend, Program.Current_View (Model));
               Queue_Command;
               exit when Transitions.Should_Quit (Next);
            end loop;
            Stop_Workers;
         exception
            when others =>
               Stop_Workers;
               raise;
         end;

         if Failure.Failed then
            raise Runner_Error with "a runner worker raised an exception";
         end if;
         Flyology_TUI.Backends.Close (Backend);
         Opened := False;
      exception
         when others =>
            Stop_Workers;
            Flyology_TUI.Backends.Close (Backend);
            Opened := False;
            raise;
      end;
   end Run;

end Flyology_TUI.Runners;
