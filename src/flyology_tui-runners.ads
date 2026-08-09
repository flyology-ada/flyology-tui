with Flyology_TUI.Application_Events;
with Flyology_TUI.Backends;
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

   --  Execute runs on one command worker. Expected failures should be encoded
   --  in Message and returned with Produced set; an escaping exception stops
   --  the runner and is reported as Runner_Error.
   with procedure Execute
     (Command  : Transitions.Command;
      Message  : out Events.Message;
      Produced : out Boolean);

   Event_Capacity   : Positive := 256;
   Command_Capacity : Positive := 64;
package Flyology_TUI.Runners is
   Runner_Error : exception;

   --  Run owns Model on the calling task. Terminal input and command execution
   --  feed a bounded inbox, while Initialize, Update, Present, and Render are
   --  invoked serially. Run restores the backend if any operation fails.
   procedure Run
     (Model   : in out Model_Type;
      Backend : in out Flyology_TUI.Backends.Backend'Class);
end Flyology_TUI.Runners;
