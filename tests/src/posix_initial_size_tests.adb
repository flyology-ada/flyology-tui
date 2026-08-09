with Ada.Text_IO;
with Flyology_TUI.Application_Events;
with Flyology_TUI.Backends.POSIX;
with Flyology_TUI.Events;
with Flyology_TUI.Runners;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Transitions;
with Flyology_TUI.Views;

procedure POSIX_Initial_Size_Tests is
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   Expected_Width : constant Natural := 91;
   Expected_Height : constant Natural := 27;
   Present_Count : Natural := 0;

   type Message is (Unused_Message);
   type Command is (Unused_Command);

   type Model is limited record
      Saw_Opening_Size : Boolean := False;
   end record;

   package Events is new Flyology_TUI.Application_Events (Message);
   package Transitions is new Flyology_TUI.Transitions (Command);
   use type Events.Event_Kind;

   procedure Initialize
     (Item : in out Model;
      Next : in out Transitions.Transition)
   is
      pragma Unreferenced (Item, Next);
   begin
      null;
   end Initialize;

   procedure Update
     (Item : in out Model;
      Event : Events.Event;
      Next : in out Transitions.Transition) is
   begin
      if Event.Kind = Events.Terminal_Input
        and then Event.Terminal.Kind = Flyology_TUI.Events.Resize
      then
         if Event.Terminal.Width /= Expected_Width
           or else Event.Terminal.Height /= Expected_Height
         then
            raise Program_Error with "POSIX opening size was incorrect";
         end if;
         Item.Saw_Opening_Size := True;
         Transitions.Quit (Next);
      end if;
   end Update;

   function Present (Item : Model) return Flyology_TUI.Views.View is
   begin
      if not Item.Saw_Opening_Size then
         raise Program_Error with
           "runner presented before dispatching the POSIX opening size";
      end if;
      Present_Count := Present_Count + 1;
      return Flyology_TUI.Views.From_Surface
        (Flyology_TUI.Surfaces.Create (Expected_Width, Expected_Height));
   end Present;

   procedure Execute
     (Item : Command;
      Result : out Message;
      Produced : out Boolean)
   is
      pragma Unreferenced (Item);
   begin
      Result := Unused_Message;
      Produced := False;
   end Execute;

   package Runtime is new Flyology_TUI.Runners
     (Events      => Events,
      Transitions => Transitions,
      Model_Type  => Model,
      Initialize  => Initialize,
      Update      => Update,
      Present     => Present,
      Execute     => Execute);

   State : Model;
   Terminal : Flyology_TUI.Backends.POSIX.POSIX_Backend;
begin
   Runtime.Run (State, Terminal);
   if not State.Saw_Opening_Size or else Present_Count /= 1 then
      raise Program_Error with "POSIX opening-size lifecycle was incomplete";
   end if;
   Ada.Text_IO.Put_Line ("POSIX initial size tests passed");
end POSIX_Initial_Size_Tests;
