package body Flyology_TUI.Application_Events is

   function From_Terminal
     (Item : Flyology_TUI.Events.Terminal_Event) return Event
   is (Kind => Terminal_Input, Terminal => Item);

   function From_Message (Item : Message_Type) return Event is
     (Kind => Application_Message, Application => Item);

end Flyology_TUI.Application_Events;
