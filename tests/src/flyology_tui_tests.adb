with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Application_Events;
with Flyology_TUI.Events;
with Flyology_TUI.Programs;
with Flyology_TUI.Transitions;
with Flyology_TUI.Views;

procedure Flyology_TUI_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   type Message is record
      Amount       : Integer := 0;
      Request_Save : Boolean := False;
   end record;

   type Command is record
      Saved_Value : Integer := 0;
   end record;

   type Model is limited record
      Count  : Integer := 0;
      Starts : Natural := 0;
   end record;

   package App_Events is new Flyology_TUI.Application_Events (Message);
   package App_Transitions is new Flyology_TUI.Transitions (Command);

   procedure Initialize
     (Item : in out Model;
      Next : in out App_Transitions.Transition)
   is
      pragma Unreferenced (Next);
   begin
      Item.Starts := Item.Starts + 1;
   end Initialize;

   procedure Update
     (Item  : in out Model;
      Event : App_Events.Event;
      Next  : in out App_Transitions.Transition)
   is
   begin
      case Event.Kind is
         when App_Events.Application_Message =>
            Item.Count := Item.Count + Event.Application.Amount;
            if Event.Application.Request_Save then
               App_Transitions.Run
                 (Next, (Saved_Value => Item.Count));
            end if;
         when App_Events.Terminal_Input =>
            if Event.Terminal.Kind = Flyology_TUI.Events.Interrupt then
               App_Transitions.Quit (Next);
            end if;
      end case;
   end Update;

   function Present (Item : Model) return Flyology_TUI.Views.View is
   begin
      if Item.Count = 3 then
         return Flyology_TUI.Views.Plain ("3");
      else
         return Flyology_TUI.Views.Plain ("other");
      end if;
   end Present;

   package Counter is new Flyology_TUI.Programs
     (Events      => App_Events,
      Transitions => App_Transitions,
      Model_Type  => Model,
      Initialize  => Initialize,
      Update      => Update,
      Present     => Present);

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   State  : Model;
   Next   : App_Transitions.Transition;
   Screen : Flyology_TUI.Views.View;
begin
   App_Transitions.Run (Next, (Saved_Value => -1));
   Counter.Start (State, Next);
   Assert (State.Starts = 1, "initialize was not called");
   Assert
     (not App_Transitions.Has_Command (Next),
      "start retained a stale command");

   Counter.Dispatch
     (State,
      App_Events.From_Message ((Amount => 3, Request_Save => False)),
      Next);
   Assert (State.Count = 3, "application message did not update model");
   Assert
     (not App_Transitions.Has_Command (Next),
      "dispatch emitted an unexpected command");

   Screen := Counter.Current_View (State);
   Assert
     (Screen.Content = Text.To_Unbounded_Wide_Wide_String ("3"),
      "view did not describe current model");

   Counter.Dispatch
     (State,
      App_Events.From_Message ((Amount => 2, Request_Save => True)),
      Next);
   Assert (App_Transitions.Has_Command (Next), "command was not emitted");
   Assert
     (App_Transitions.Pending_Command (Next).Saved_Value = 5,
      "command did not capture updated model state");

   Counter.Dispatch
     (State,
      App_Events.From_Terminal ((Kind => Flyology_TUI.Events.Interrupt)),
      Next);
   Assert
     (App_Transitions.Should_Quit (Next),
      "interrupt did not request quit");
end Flyology_TUI_Tests;
