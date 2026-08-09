with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Flyology_TUI.Events;

package Flyology_TUI.Input is
   use type Flyology_TUI.Events.Terminal_Event;

   type Parser is tagged private;

   procedure Initialize
     (Item            : in out Parser;
      Max_Paste_Bytes : Positive := 1_048_576);

   procedure Feed (Item : in out Parser; Data : String);

   --  Resolve a pending escape byte as Escape rather than waiting for a
   --  possible sequence suffix. A backend calls this after its escape delay.
   procedure Flush_Escape (Item : in out Parser);

   function Has_Event (Item : Parser) return Boolean;

   procedure Next_Event
     (Item      : in out Parser;
      Event     : out Flyology_TUI.Events.Terminal_Event;
      Available : out Boolean);

   procedure Reset (Item : in out Parser);

private
   package Event_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Flyology_TUI.Events.Terminal_Event,
      "="          => Flyology_TUI.Events."=");

   type Parser is tagged record
      Buffer          : Ada.Strings.Unbounded.Unbounded_String;
      Events          : Event_Vectors.Vector;
      In_Paste        : Boolean := False;
      Paste_Buffer    : Ada.Strings.Unbounded.Unbounded_String;
      Max_Paste_Bytes : Positive := 1_048_576;
   end record;
end Flyology_TUI.Input;
