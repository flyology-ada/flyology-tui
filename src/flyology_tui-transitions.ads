generic
   type Command_Type is private;
package Flyology_TUI.Transitions is
   subtype Command is Command_Type;

   --  One command request emitted by an update. Command_Type may itself encode
   --  batching or sequencing, matching the single-command transition used by
   --  Elm-style runtimes without making command payloads dynamically typed.
   type Transition is tagged private;

   procedure Reset (Item : in out Transition);
   procedure Run (Item : in out Transition; Command : Command_Type);
   procedure Quit (Item : in out Transition);

   function Has_Command (Item : Transition) return Boolean;
   function Pending_Command (Item : Transition) return Command_Type
     with Pre => Has_Command (Item);
   function Should_Quit (Item : Transition) return Boolean;

private
   type Transition is tagged record
      Command_Set   : Boolean := False;
      Command_Value : Command_Type;
      Quit_Set      : Boolean := False;
   end record;
end Flyology_TUI.Transitions;
