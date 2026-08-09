package body Flyology_TUI.Transitions is

   procedure Reset (Item : in out Transition) is
   begin
      Item.Command_Set := False;
      Item.Quit_Set := False;
   end Reset;

   procedure Run (Item : in out Transition; Command : Command_Type) is
   begin
      Item.Command_Value := Command;
      Item.Command_Set := True;
   end Run;

   procedure Quit (Item : in out Transition) is
   begin
      Item.Quit_Set := True;
   end Quit;

   function Has_Command (Item : Transition) return Boolean is
     (Item.Command_Set);

   function Pending_Command (Item : Transition) return Command_Type is
     (Item.Command_Value);

   function Should_Quit (Item : Transition) return Boolean is
     (Item.Quit_Set);

end Flyology_TUI.Transitions;
