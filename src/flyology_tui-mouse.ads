with Flyology_TUI.Events;

package Flyology_TUI.Mouse is
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   type Region is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   --  Return whether a terminal-cell coordinate lies inside Region.
   function Contains
     (Item : Region;
      X, Y : Natural) return Boolean;

   --  Return whether a mouse event lies inside Region.
   function Contains
     (Item  : Region;
      Event : Flyology_TUI.Events.Mouse_Event) return Boolean;

   --  Translate a mouse event from terminal coordinates to Region-relative
   --  coordinates. Modifiers, button state, action, and wheel deltas survive.
   function Localize
     (Event : Flyology_TUI.Events.Mouse_Event;
      Item  : Region) return Flyology_TUI.Events.Mouse_Event
     with Pre => Contains (Item, Event);

   --  Localize the mouse payload of a terminal event.
   function Localize
     (Event : Flyology_TUI.Events.Terminal_Event;
      Item  : Region) return Flyology_TUI.Events.Terminal_Event
     with Pre =>
       Event.Kind = Flyology_TUI.Events.Mouse_Input
       and then Contains (Item, Event.Mouse);
end Flyology_TUI.Mouse;
