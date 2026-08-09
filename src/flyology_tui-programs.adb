package body Flyology_TUI.Programs is

   procedure Start
     (Model : in out Model_Type;
      Next  : in out Transitions.Transition)
   is
   begin
      Transitions.Reset (Next);
      Initialize (Model, Next);
   end Start;

   procedure Dispatch
     (Model : in out Model_Type;
      Event : Events.Event;
      Next  : in out Transitions.Transition)
   is
   begin
      Transitions.Reset (Next);
      Update (Model, Event, Next);
   end Dispatch;

   function Current_View
     (Model : Model_Type) return Flyology_TUI.Views.View
   is (Present (Model));

end Flyology_TUI.Programs;
