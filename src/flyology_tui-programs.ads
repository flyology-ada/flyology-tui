with Flyology_TUI.Application_Events;
with Flyology_TUI.Transitions;
with Flyology_TUI.Views;

generic
   with package Events is new Flyology_TUI.Application_Events (<>);
   with package Transitions is new Flyology_TUI.Transitions (<>);
   type Model_Type is limited private;

   with procedure Initialize
     (Model : in out Model_Type;
      Next  : in out Transitions.Transition);

   with procedure Update
     (Model : in out Model_Type;
      Event : Events.Event;
      Next  : in out Transitions.Transition);

   with function Present
     (Model : Model_Type) return Flyology_TUI.Views.View;
package Flyology_TUI.Programs is
   --  Start and Dispatch never perform I/O or execute commands. The caller is
   --  the sole model owner and passes emitted commands to an executor. Command
   --  results return through Events.From_Message.
   procedure Start
     (Model : in out Model_Type;
      Next  : in out Transitions.Transition);

   procedure Dispatch
     (Model : in out Model_Type;
      Event : Events.Event;
      Next  : in out Transitions.Transition);

   function Current_View
     (Model : Model_Type) return Flyology_TUI.Views.View;
end Flyology_TUI.Programs;
