with Flyology_TUI.Events;

generic
   type Message_Type is private;
package Flyology_TUI.Application_Events is
   subtype Message is Message_Type;

   type Event_Kind is (Terminal_Input, Application_Message);

   type Event (Kind : Event_Kind := Terminal_Input) is record
      case Kind is
         when Terminal_Input =>
            Terminal : Flyology_TUI.Events.Terminal_Event;
         when Application_Message =>
            Application : Message_Type;
      end case;
   end record;

   function From_Terminal
     (Item : Flyology_TUI.Events.Terminal_Event) return Event;

   function From_Message (Item : Message_Type) return Event;
end Flyology_TUI.Application_Events;
