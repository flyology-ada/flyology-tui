with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Flyology_TUI.Events;

package Flyology_TUI.Input is
   use type Flyology_TUI.Events.Terminal_Event;

   Input_Error : exception;

   type Parser is tagged private;

   procedure Initialize
     (Item              : in out Parser;
      Max_Paste_Bytes   : Positive := 1_048_576;
      Max_Pending_Bytes : Positive := 16_384;
      Max_Queued_Events : Positive := 4_096);

   --  Feed raises Input_Error before accepting a fragment that would exceed
   --  Max_Pending_Bytes, or before adding an event beyond Max_Queued_Events.
   --  Callers may feed larger reads as multiple bounded fragments.
   procedure Feed (Item : in out Parser; Data : String);

   --  Resolve the leading escape of an incomplete sequence as Escape, then
   --  parse its remaining bytes normally. A backend calls this after its
   --  escape delay.
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
      Max_Pending_Bytes : Positive := 16_384;
      Max_Queued_Events : Positive := 4_096;
   end record;
end Flyology_TUI.Input;
